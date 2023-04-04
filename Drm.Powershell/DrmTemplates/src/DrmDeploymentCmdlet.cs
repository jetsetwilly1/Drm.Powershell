using drmDeployment.Services.Exceptions;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Net.Http;
using System.Threading.Tasks;

namespace drm.Powershell.DrmTemplates
{
    //https://www.red-gate.com/simple-talk/dotnet/net-development/using-c-to-create-powershell-cmdlets-the-basics/
    //https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/create-standard-library-binary-module?view=powershell-7.1
    //https://www.reddit.com/r/PowerShell/comments/bp5rbh/powershell_binary_modules_and_scripted_cmdlets/

    [Cmdlet(VerbsCommon.New, "DrmDeployment")]
    [CmdletBinding]
    public class DrmDeploymentCmdlet : PSCmdlet
    {
        [Parameter(Mandatory = true, HelpMessage = "Local path to the template file. Supported template file type: json")]
        public string TemplateFile { get; set; }

        [Parameter(HelpMessage = "A file that has the template parameters.")]
        public string TemplateParameterFile { get; set; }

        [Parameter(HelpMessage = "A hash table which represents the parameters.")]
        public Hashtable TemplateParameterObject { get; set; }

        [Parameter(Mandatory = false, HelpMessage = "Your subscription id for executing deployments.")]
        public string SubscriptionId { get; set; }

        [Parameter(DontShow = true, HelpMessage = "Output log to console.")]
        public SwitchParameter OutputLogToConsole { get; set; }

        [Parameter(DontShow = true, HelpMessage = "If set to true it will use the beta/test environment.")]
        public SwitchParameter UseBetaEnvironment { get; set; }

        [Parameter(DontShow = true, HelpMessage = "If set to true it will not attempt to log into Azure.")]
        public SwitchParameter SkipAzureLogin { get; set; }


        private readonly string _parametersJsonContentVersion = "1.0.0.0";

        private Containers.DrmEnvironment _envVariables = null;

        private string _kvAccessToken;

        private string _logUrl;

        private bool _jobCompleted;

        private PowershellDeployment _powershellDeployment;

        protected override async void ProcessRecord()
        {
            // set environment variables
            Environment.SetEnvironmentVariable("ParallelDeployGroupBatch", "5");

            JObject templateParamsJson = new JObject();
            JObject templateJson = new JObject();

            // process parameters and templates
            try
            {
                if (!string.IsNullOrEmpty(TemplateFile))
                {
                    templateJson = JObject.Parse(File.ReadAllText(TemplateFile));
                }

                if (!string.IsNullOrEmpty(TemplateParameterFile))
                {
                    templateParamsJson = JObject.Parse(File.ReadAllText(TemplateParameterFile));
                }

                if (templateParamsJson.Count == 0) // if no file was present, check for params object and populate..
                {
                    if (TemplateParameterObject != null && TemplateParameterObject.Count > 0)
                    {
                        JObject jsonParams = new JObject();

                        foreach (string paramName in TemplateParameterObject.Keys)
                        {
                            var valueObj = new JObject();
                            var jToken = JToken.FromObject(TemplateParameterObject[paramName]);
                            valueObj.Add("value", jToken);

                            jsonParams.Add(paramName, valueObj);
                        }

                        string paramsJsonSchemaUrl = "https://schemas.drmtemplates.io/2021-03-01/deploymentParameters.json#";

                        WriteVerbose("No Parameters file present, setting parameters schema url to default: '" + paramsJsonSchemaUrl + "'");
                        WriteVerbose("No Parameters file present, setting parameters contentVersion: " + _parametersJsonContentVersion);

                        templateParamsJson.Add("$schema", paramsJsonSchemaUrl);
                        templateParamsJson.Add("contentVersion", _parametersJsonContentVersion);
                        templateParamsJson.Add("parameters", jsonParams);
                    }
                }
                else // params file was present, are there any additions/overrides to include
                {
                    if (TemplateParameterObject != null && TemplateParameterObject.Count > 0)
                    {
                        // do replacements or additions
                        foreach (string paramName in TemplateParameterObject.Keys)
                        {
                            // replace any from the params object
                            var param = templateParamsJson.SelectTokens("parameters").Children()
                                .Where(x => x.Value<JProperty>().Name == paramName).FirstOrDefault();

                            if (param != null)
                            {
                                var valueObj = new JObject();
                                var jToken = JToken.FromObject(TemplateParameterObject[paramName]);
                                valueObj.Add("value", jToken);
                                param.Value<JProperty>().Value = valueObj;
                            }
                            else
                            {
                                // add it
                                var valueObj = new JObject();
                                var jToken = JToken.FromObject(TemplateParameterObject[paramName]);
                                valueObj.Add("value", jToken);
                                var newParam = new JProperty(paramName, valueObj);
                                var existingparams = templateParamsJson.SelectTokens("parameters").FirstOrDefault();

                                ((JObject)existingparams).Add(newParam);
                            }

                        }
                    }
                }
            }
            catch (Exception e)
            {
                ThrowTerminatingError(new ErrorRecord(e, "ProcessingTemplates", ErrorCategory.InvalidOperation, null));
            }

            try
            {
                // check to see if we need to get an azure token
                if (templateParamsJson.Count != 0)
                {
                    var parametersObj = templateParamsJson.Value<JObject>("parameters");
                    
                    if(parametersObj != null)
                    {
                        foreach (var item in parametersObj.Children())
                        {
                            var param = item.Value<JProperty>();
                            var paramValObj = param.Value as JObject;

                            if (paramValObj.ContainsKey("reference"))
                            {
                                Console.ForegroundColor = ConsoleColor.Green;
                                Console.WriteLine("Keyvault references found in parameter set, attempting to generate Azure token...");
                                Console.ResetColor();
                                GetAzureToken();
                                break;
                            }
                        }
                    }
                }

                // now build request
                var requestjson = new Containers.DeployRequest
                {
                    Template = templateJson,
                    Parameters = templateParamsJson
                };

                var jsonBody = JsonConvert.SerializeObject(requestjson);

                var verboseLogging = false;

                if (MyInvocation.BoundParameters.ContainsKey("Verbose")) verboseLogging = true;

                _powershellDeployment = new PowershellDeployment(verboseLogging);

                _powershellDeployment.KeyVaultAccessToken = _kvAccessToken;

                var instanceId = _powershellDeployment.StartJob(jsonBody);

                do
                {
                    GetLogUpdates();
                    Task.Delay(2000).GetAwaiter().GetResult();

                } while (_jobCompleted != true);

                if (_powershellDeployment.DeploymentFailed)
                {
                    _powershellDeployment.LogEntries.Clear();
                    Console.WriteLine();
                    ThrowTerminatingError(new ErrorRecord(new DeploymentException(), "Job failed. Check the log for errors.", ErrorCategory.InvalidOperation, null));
                }
            }
            catch (Exception e)
            {
                if (e.InnerException != null)
                {
                    if (e.InnerException.GetType() == typeof(HttpRequestException))
                    {
                        WriteWarning("HttpRequestException thrown, unable to contact the deployment api, please report this to a system administrator and try again later.");
                        ThrowTerminatingError(new ErrorRecord(e.InnerException, "SendingJob", ErrorCategory.InvalidOperation, null));
                    }
                    else
                        GetErrorLogs();
                }
                else if (e.GetType() == typeof(HttpRequestException))
                {
                    WriteWarning("HttpRequestException thrown, most likely cause is that the subscription key is incorrect.");
                }
                else
                    GetErrorLogs();

                if (e.GetType() != typeof(PipelineStoppedException))
                    ThrowTerminatingError(new ErrorRecord(e, "SendingJob", ErrorCategory.InvalidOperation, null));
                
            }
        }

        private void GetAzureToken()
        {
            // try and get key vault token
            try
            {
                if (SkipAzureLogin)
                {
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("Skipping Azure login...");
                    Console.ResetColor();
                }
                else
                {
                    var kvCommandParams = new List<CommandParameter>() { new CommandParameter("ErrorAction", "Stop") };

                    if (MyInvocation.BoundParameters.ContainsKey("Verbose"))
                        kvCommandParams.Add(new CommandParameter("Verbose", true));


                    var kvResult = RunScript("Get-KvAccessToken", kvCommandParams);

                    if (kvResult.Count == 1)
                    {
                        foreach (var result in kvResult)
                        {
                            _kvAccessToken = result.ToString();
                        }

                        WriteVerbose("Azure access token  `n" + _kvAccessToken);

                        Console.ForegroundColor = ConsoleColor.Green;
                        Console.WriteLine("Successfully retrieved Azure token.");
                        Console.ResetColor();
                    }
                    else
                    {
                        ThrowTerminatingError(new ErrorRecord(new SystemException("Keyvault parameters were detected in your parameter set, please connect to your azure instance using Connect-AzAccount -TenantId 00000000-0000-0000-0000-000000.  You may need to reconnect to Azure if your credentials have expired."), "CannotFetchAzureAccessToken", ErrorCategory.ConnectionError, null));
                    }

                }
            }
            catch (Exception e)
            {
                ThrowTerminatingError(new ErrorRecord(e, "CannotFetchAzureAccessToken", ErrorCategory.ConnectionError, null));
            }
        }

        private void GetErrorLogs()
        {
            if (_powershellDeployment != null && _powershellDeployment.LogEntries.Count > 0)
                GetLogUpdates();
        }

        private void GetLogUpdates()
        {
            if (_powershellDeployment.LogEntries.Count > 0)
            {
                var orderedLog = _powershellDeployment.LogEntries.OrderBy(x => x.TimeStamp);

                var logs = orderedLog.ToList();

                foreach (var l in logs)
                {
                    var message = l.Log;
                    message = "[datetime]" + message;


                    if (message.Contains("[inf]"))
                        message = message.Replace("[inf] ", "");

                    if (message.Contains("[error]") || message.Contains("[exception]"))
                    {
                        message = message.Replace("[error] ", "");
                        message = message.Replace("[exception] ", "");
                        Console.ForegroundColor = ConsoleColor.Red;
                    }

                    if (message.Contains("[warning]"))
                    {
                        message = message.Replace("[warning] ", "");
                        Console.ForegroundColor = ConsoleColor.Yellow;
                    }

                    if (message.Contains("[verbose]"))
                    {
                        message = message.Replace("[verbose] ", "VERBOSE: ");
                        message = message.Replace("[datetime]", "");
                        Console.ForegroundColor = ConsoleColor.Yellow;
                    }

                    if (message.Contains("[SUMMARY]") && _jobCompleted != true)
                    {
                        message = message.Replace("[SUMMARY]", "").TrimStart();
                        message = message.Replace("[datetime]", "");
                        Console.WriteLine();
                        _jobCompleted = true;
                    }

                    if (message.Contains("[NOPREFIX]"))
                        message = message.Replace("[NOPREFIX]", "").TrimStart();

                    message = message.Replace("[datetime]", DateTime.Now.ToString() + " ");

                    Console.WriteLine(message);
                    Console.ResetColor();

                    _powershellDeployment.LogEntries.Remove(l);

                    if (_jobCompleted) break;
                }
            }
        }

        /// <summary>
        /// Runs a PowerShell script taking it's path and parameters.
        /// </summary>
        /// <param name="scriptFullPath">The full file path for the .ps1 file.</param>
        /// <param name="parameters">The parameters for the script, can be null.</param>
        /// <returns>The output from the PowerShell execution.</returns>
        private static ICollection<PSObject> RunScript(string command, ICollection<CommandParameter> parameters = null)
        {
            PowerShell ps = PowerShell.Create(RunspaceMode.CurrentRunspace);
            ps.AddCommand(command);
            if (parameters != null)
            {
                foreach (var p in parameters)
                {
                    if (p.Value != null)
                        ps.AddParameter(p.Name, p.Value);
                    else
                        ps.AddArgument(p.Name);
                }
            }

            var result = ps.Invoke();

            return result;
        }
    }
}

namespace drm.Powershell.DrmTemplates.Containers
{
    public class DeployRequest
    {
        [JsonProperty("template")]
        public JObject Template { get; set; }

        [JsonProperty("parameters")]
        public JObject Parameters { get; set; }
    }

    public class DrmEnvironment
    {
        public string DeployBaseUrl { get; set; }
        public string DeploymentPrefixRelativeUrl { get; set; }
        public string DeploymentRelativeUrl { get; set; }
        public string SchemaBaseUrl { get; set; }
    }
}