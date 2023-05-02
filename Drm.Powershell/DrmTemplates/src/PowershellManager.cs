using drm.Core.Models;
using drm.Core.Models.Logging;
using drm.Core.Services;
using drmDeployment.Services;
using drmDeployment.Services.Exceptions;
using drmDeployment.Services.Models;
using drmTemplates.OData.Services;
using drmTemplates.OData.Services.Models;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;

namespace drm.Powershell.DrmTemplates
{
    public class PowershellGenerateTemplate
    {
        private readonly GenerateTemplateService _templateService;

        public List<LogEntry> LogEntries = new List<LogEntry>();

        public PowershellGenerateTemplate(bool verboseLogging)
        {
            var logToConsoleService = new LogToMemoryService(LogEntries);
            var clientLogger = new ClientLogger(logToConsoleService);
            var odataStateEntity = new ODataStateEntity();
            var dynamicsWebApiLogger = new WebApiLogger(odataStateEntity);
            var templateLogger = new PowershellLoggerFacade<GenerateTemplateService>(clientLogger, dynamicsWebApiLogger, verboseLogging);
            var dynamicsHttpLogger = new PowershellLoggerFacade<DynamicsHttpClient>(clientLogger, dynamicsWebApiLogger, verboseLogging);
            var httpClient = new HttpClient();
            var dynamicsHttpClient = new DynamicsHttpClient(dynamicsHttpLogger, httpClient);

            var entityApi = new EntityApi(dynamicsHttpClient, odataStateEntity);

            _templateService = new GenerateTemplateService(templateLogger, entityApi);
        }
        public string Template = string.Empty;

        public async Task<string> GenerateTemplateAsync(string filter)
        {
            var r = await _templateService.GenerateTemplate(filter) as ResponseEnvelopeResult<GenerateTemplateResponseModel>;
            var resp = r.Value as ResponseEnvelope<GenerateTemplateResponseModel>;
            
            if(r.StatusCode == 200)
            {
                Template = resp.Data.Template;
                // remove template before returning resp
                resp.Data.Template = "{}";
            }           

            return JsonConvert.SerializeObject(resp);
        }

        public void WriteTemplateToFile(string location)
        {
            var responseData = JsonConvert.DeserializeObject(Template);

            string jsonData = JsonConvert.SerializeObject(responseData, Formatting.Indented);

            File.WriteAllText(location, jsonData);
        }
    }


    public class PowershellDeployment
    {
        // loggers
        private readonly PowershellLoggerFacade<PowershellDeployment> _powershellDeploymentLogger;

        // services
        private readonly TemplateService _templateService;
        private readonly CompilerService _compilerService;
        private readonly PowershellDeploymentManagerService _deploymentManagerService;
        private static Random random = new Random();

        // public props
        public string KeyVaultAccessToken { get; set; }
        public List<LogEntry> LogEntries = new List<LogEntry>();
        public bool DeploymentFailed { get; set; }

        public PowershellDeployment(bool verboseLogging)
        {
            var _logToConsoleService = new LogToMemoryService(LogEntries);
            var _clientLogger = new ClientLogger(_logToConsoleService);
            var _odataStateEntity = new ODataStateEntity();
            var _dynamicsWebApiLogger = new WebApiLogger(_odataStateEntity);

            _powershellDeploymentLogger = new PowershellLoggerFacade<PowershellDeployment>(_clientLogger, _dynamicsWebApiLogger, verboseLogging);
            var templateLogger = new PowershellLoggerFacade<DeploymentModel>(_clientLogger, _dynamicsWebApiLogger, verboseLogging);
            var validationLogger = new PowershellLoggerFacade<SchemaValidationService>(_clientLogger, _dynamicsWebApiLogger, verboseLogging);
            var compilerLogger = new PowershellLoggerFacade<CompilerService>(_clientLogger, _dynamicsWebApiLogger, verboseLogging);
            var jintClientLogger = new PowershellLoggerFacade<JintClientService>(_clientLogger, _dynamicsWebApiLogger, verboseLogging);

            var httpClient = new HttpClient();

            var azureClient = new AzureClientService();
            var javaClientService = new JintClientService(jintClientLogger);
            var schemaValidationService = new SchemaValidationService(validationLogger, httpClient);
            _templateService = new TemplateService(templateLogger, schemaValidationService);
            _compilerService = new CompilerService(javaClientService, compilerLogger, schemaValidationService, azureClient);

            _deploymentManagerService = new PowershellDeploymentManagerService(LogEntries, verboseLogging);
        }

        /// <summary>
        /// Entrypoint into the deployment process
        /// </summary>
        /// <param name="requestBody"></param>
        /// <returns></returns>
        public string StartJob(string requestBody)
        {
            var instanceId = RandomString(32);

            ProcessDeploymentRequest(requestBody, instanceId);

            return instanceId;
        }

        /// <summary>
        /// Run the deployment given the template.
        /// </summary>
        /// <param name="requestBody"></param>
        /// <param name="instanceId"></param>
        /// <returns></returns>
        private async Task<bool> ProcessDeploymentRequest(string requestBody, string instanceId)
        {
            if (!string.IsNullOrEmpty(KeyVaultAccessToken))
            {
                var json = "{ 'keyVaultAccessToken': '" + KeyVaultAccessToken + "' }";

                var request = JsonConvert.DeserializeObject<JObject>(requestBody);

                request.Add("azureProfile", JsonConvert.DeserializeObject<JObject>(json));

                requestBody = JsonConvert.SerializeObject(request);
            }

            var drmTemplate = await BuildTemplateModel(requestBody, instanceId);

            var totalOdataCount = 0;

            if (drmTemplate != null)
            {
                var resultLog = new List<DeployLog>();

                // resources are sorted into groups evaluating any dependancies ready for deployment
                var deploymentJobs = GetDeploymentJobGroups(instanceId, drmTemplate);

                var resourcesTotal = drmTemplate.Resources.Count;

                foreach (var group in deploymentJobs)
                {
                    var resultResourcesInBatches = GetResourcesForDeploymentByBatch(instanceId, group);

                    var deployLogs = new DeployGroupData { Log = new List<DeployLog>() };

                    // now deploy each batch of resources
                    foreach (var resources in resultResourcesInBatches)
                    {
                        var batchLog = await DeployGroupedResourcesInParallel(instanceId, resources);

                        foreach (var l in batchLog.Log)
                        {
                            if (l.Response != null)
                            {
                                totalOdataCount += (int)((dynamic)l.Response).Data.ODataRequestCount;

                                totalOdataCount += (int)((dynamic)l.Response).Data.ODataInternalRequestCount;
                            }
                        }

                        deployLogs.Log.AddRange(batchLog.Log);

                        if (batchLog.Status != DeployGroupData.StatusType.Ok)
                        {
                            deployLogs.Status = batchLog.Status;
                            // errors so break out and report back to client
                            break;
                        }
                    }

                    if (deployLogs.Status == DeployGroupData.StatusType.Ok)
                        resultLog.AddRange(deployLogs.Log);
                    else
                    {
                        if (deployLogs.Status == DeployGroupData.StatusType.ExceptionThrown)
                        {
                            _powershellDeploymentLogger.LogError((int)Log.DeploymentMgrEventId.DeploymentManager,
                                Log.Template + "{instanceId} Workflow failed. An Exception was thrown during the deployment phase.  Likely cause is Entity api(s) unavailable.",
                            Log.Status.Failed, instanceId);

                            _powershellDeploymentLogger.ClientJobId = instanceId;
                            _powershellDeploymentLogger.LogTo = LogType.ToClient;
                            _powershellDeploymentLogger.LogError((int)Log.DeploymentMgrEventId.DeploymentManager,
                                "[NOPREFIX][SUMMARY]\r\nJobId: {instanceId}\r\nStatus: {JobStatus}\r\nTotal OData Requests: {totalRequests}\r\nMessage: There was a problem with the deployment workflow, please contact an administrator.",
                                instanceId, HttpStatusCode.InternalServerError, totalOdataCount);

                            DeploymentFailed = true;
                            return false;
                        }

                        if (deployLogs.Status == DeployGroupData.StatusType.Failures)
                        {
                            _powershellDeploymentLogger.LogWarning((int)Log.DeploymentMgrEventId.DeploymentManager,
                                Log.Template + "{instanceId} Workflow failed. Client notified of issues.",
                                Log.Status.Discarded, instanceId);


                            _powershellDeploymentLogger.ClientJobId = instanceId;
                            _powershellDeploymentLogger.LogTo = LogType.ToClient;
                            _powershellDeploymentLogger.LogError((int)Log.DeploymentMgrEventId.DeploymentManager,
                                "[NOPREFIX][SUMMARY]\r\nJobId: {instanceId}\r\nStatus: {JobStatus}\r\nTotal OData Requests: {totalRequests}\r\nMessage: Failures were found during deployment, please check the log for errors.",
                                instanceId, HttpStatusCode.BadRequest, totalOdataCount);

                            DeploymentFailed = true;
                            return false;
                        }
                    }
                }

                _powershellDeploymentLogger.ClientJobId = instanceId;
                _powershellDeploymentLogger.LogTo = LogType.ToClient;
                _powershellDeploymentLogger.LogInformation((int)Log.DeploymentMgrEventId.DeploymentManager,
                    "[NOPREFIX][SUMMARY]\r\nJobId: {instanceId}\r\nStatus: {JobStatus}\r\nTotal OData Requests: {totalRequests}\r\nMessage: Deployment successful",
                    instanceId, HttpStatusCode.OK, totalOdataCount);

                return true;
            }
            else
            {
                _powershellDeploymentLogger.ClientJobId = instanceId;
                _powershellDeploymentLogger.LogTo = LogType.ToClient;
                _powershellDeploymentLogger.LogError((int)Log.DeploymentMgrEventId.DeploymentManager,
                    "[NOPREFIX][SUMMARY]\r\nJobId: {instanceId}\r\nStatus: {JobStatus}\r\nTotal OData Requests: {totalRequests}\r\nMessage: Validation failed, please check the log for errors.",
                    instanceId, HttpStatusCode.BadRequest, totalOdataCount);

                DeploymentFailed = true;
                return false;
            }
        }

        private async Task<DeployGroupData> DeployGroupedResourcesInParallel(string instanceId, IList<Resource> resources)
        {
            try
            {
                _deploymentManagerService.InitialiseJob(instanceId);

                var data = await _deploymentManagerService.DeployResources(resources);

                return data;
            }
            catch (DeploymentException e)
            {
                // return the log, orchestrator will handle it
                return e.Information.DeploymentLog;
            }
        }

        private IList<IList<Resource>> GetResourcesForDeploymentByBatch(string instanceId, ICollection<Resource> resources)
        {
            _deploymentManagerService.InitialiseJob(instanceId);

            var result = _deploymentManagerService.GetResourcesForDeploymentByBatch(resources);

            return result;
        }

        private IList<ICollection<Resource>> GetDeploymentJobGroups(string instanceId, DrmTemplate drmTemplate)
        {
            _deploymentManagerService.InitialiseJob(instanceId);

            var result = _deploymentManagerService.GetDeploymentOrder(drmTemplate);

            return result;
        }

        private async Task<DrmTemplate> BuildTemplateModel(string requestBody, string instanceId)
        {
            var model = await _templateService.BuildDeploymentModel(requestBody, instanceId);

            if (_templateService.HasErrors)
            {
                //var templateErrors = JsonConvert.SerializeObject(new ResponseEnvelope<ExceptionData>(_templateService.Error.Data, _templateService.Error.Message, HttpStatusCode.BadRequest.ToString()));

                // log errors to client log
                _powershellDeploymentLogger.ClientJobId = instanceId;
                _powershellDeploymentLogger.LogTo = LogType.ToClient;
                _powershellDeploymentLogger.LogError((int)Log.DeploymentMgrEventId.Validation,
                             Log.Template + "{validationErrors}",
                Log.Status.Failed, _templateService.Error.Message);

                return null;
            }

            _powershellDeploymentLogger.ClientJobId = instanceId;
            _powershellDeploymentLogger.LogTo = LogType.ToClient;
            _powershellDeploymentLogger.LogInformation((int)Log.DeploymentMgrEventId.Processing,
                         Log.Template + "Start template compilation...",
                         Log.Status.Information);

            var deployJob = await _compilerService.ProcessTemplate(model, instanceId);

            if (model != null)
            {
                if (_compilerService.HasErrors)
                {
                    // log errors to client log
                    _powershellDeploymentLogger.ClientJobId = instanceId;
                    _powershellDeploymentLogger.LogTo = LogType.ToClient;
                    _powershellDeploymentLogger.LogError((int)Log.DeploymentMgrEventId.Validation,
                                 Log.Template + "{validationErrors}",
                                 Log.Status.Failed, _compilerService.Error.Message);

                    //var compilerErrors = JsonConvert.SerializeObject(new ResponseEnvelope<ExceptionData>(_compiler.Error.Data, _compiler.Error.Message, HttpStatusCode.BadRequest.ToString()));
                    return null;
                }
            }

            _powershellDeploymentLogger.ClientJobId = instanceId;
            _powershellDeploymentLogger.LogTo = LogType.ToClient;
            _powershellDeploymentLogger.LogInformation((int)Log.DeploymentMgrEventId.Processing,
                                Log.Template + "Template accepted.  Getting ready to deploy...",
                                Log.Status.Succeeded);

            return deployJob;
        }

        private string RandomString(int length)
        {
            const string chars = "abcdefghijklmnopqrstuvwxyz0123456789";
            return new string(Enumerable.Repeat(chars, length)
                .Select(s => s[random.Next(s.Length)]).ToArray());
        }
    }
}
