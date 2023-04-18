using System;
using System.IO;
using System.Management.Automation;
using System.Reflection;

namespace drm.Powershell
{
    // Register the event handler as early as you can in your code.
    // A good option is to use the IModuleAssemblyInitializer interface
    // that PowerShell provides to run code early on when your module is loaded.

    // This class will be instantiated on module import and the OnImport() method run.
    // Make sure that:
    //  - the class is public
    //  - the class has a public, parameterless constructor
    //  - the class implements IModuleAssemblyInitializer
    public class MyModuleInitializer : IModuleAssemblyInitializer
    {
        public void OnImport()
        {
            AppDomain.CurrentDomain.AssemblyResolve += DependencyResolution.ResolveDlls;
        }
    }

    // Clean up the event handler when the the module is removed
    // to prevent memory leaks.
    //
    // Like IModuleAssemblyInitializer, IModuleAssemblyCleanup allows
    // you to register code to run when a module is removed (with Remove-Module).
    // Make sure it is also public with a public parameterless contructor
    // and implements IModuleAssemblyCleanup.
    public class MyModuleCleanup : IModuleAssemblyCleanup
    {
        public void OnRemove(PSModuleInfo psModuleInfo)
        {
            AppDomain.CurrentDomain.AssemblyResolve -= DependencyResolution.ResolveDlls;
        }
    }

    internal static class DependencyResolution
    {
        private static readonly string s_modulePath = Path.GetDirectoryName(
            Assembly.GetExecutingAssembly().Location);

        public static Assembly ResolveDlls(object sender, ResolveEventArgs args)
        {
            // Parse the assembly name
            var assemblyName = new AssemblyName(args.Name);

            // We only want to handle the dependency we care about.
            // In this example it's Newtonsoft.Json.
            if (!assemblyName.Name.Equals("Newtonsoft.Json")
                && !assemblyName.Name.Equals("Azure.Core")
                && !assemblyName.Name.Equals("Newtonsoft.Json.Schema")
                && !assemblyName.Name.Equals("System.Memory")
                && !assemblyName.Name.Equals("System.Diagnostics.DiagnosticSource")
                && !assemblyName.Name.Equals("System.Runtime.CompilerServices.Unsafe")
                && !assemblyName.Name.Equals("System.Buffers")
                && !assemblyName.Name.Equals("System.Numerics.Vectors")
                && !assemblyName.Name.Equals("System.Text.Json")
                && !assemblyName.Name.Equals("Microsoft.Identity.Client")
                && !assemblyName.Name.Equals("Microsoft.IdentityModel.Abstractions"))
            {
                return null;
            }

            // Generally the version of the dependency you want to load is the higher one,
            // since it's the most likely to be compatible with all dependent assemblies.
            // The logic here assumes our module always has the version we want to load.
            // Also note the use of Assembly.LoadFrom() here rather than Assembly.LoadFile().
            if (assemblyName.Name.Equals("Newtonsoft.Json"))
                return Assembly.LoadFrom(Path.Combine(s_modulePath, "Newtonsoft.Json.dll"));

            if (assemblyName.Name.Equals("System.Memory"))
                return Assembly.LoadFrom(Path.Combine(s_modulePath, "System.Memory.dll"));

            if (assemblyName.Name.Equals("System.Diagnostics.DiagnosticSource"))
                return Assembly.LoadFrom(Path.Combine(s_modulePath, "System.Diagnostics.DiagnosticSource.dll"));

            if (assemblyName.Name.Equals("System.Runtime.CompilerServices.Unsafe"))
                return Assembly.LoadFrom(Path.Combine(s_modulePath, "System.Runtime.CompilerServices.Unsafe.dll"));

            if (assemblyName.Name.Equals("System.Buffers"))
                return Assembly.LoadFrom(Path.Combine(s_modulePath, "System.Buffers.dll"));

            if (assemblyName.Name.Equals("Azure.Core"))
                return Assembly.LoadFrom(Path.Combine(s_modulePath, "Azure.Core.dll"));

            if (assemblyName.Name.Equals("System.Numerics.Vectors"))
                return Assembly.LoadFrom(Path.Combine(s_modulePath, "System.Numerics.Vectors.dll"));

            if (assemblyName.Name.Equals("Microsoft.IdentityModel.Abstractions"))
                return Assembly.LoadFrom(Path.Combine(s_modulePath, "Microsoft.IdentityModel.Abstractions.dll"));

            if (assemblyName.Name.Equals("Newtonsoft.Json.Schema"))
                return Assembly.LoadFrom(Path.Combine(s_modulePath, "Newtonsoft.Json.Schema.dll"));

            if (assemblyName.Name.Equals("Microsoft.Identity.Client"))
                return Assembly.LoadFrom(Path.Combine(s_modulePath, "Microsoft.Identity.Client.dll"));

            if (assemblyName.Name.Equals("System.Text.Json"))
                return Assembly.LoadFrom(Path.Combine(s_modulePath, "System.Text.Json.dll"));


            return null;
        }
    }
}
