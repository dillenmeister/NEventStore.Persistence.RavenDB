properties {
    $base_directory = Resolve-Path .. 
	$publish_directory = "$base_directory\publish-net40"
	$build_directory = "$base_directory\build"
	$src_directory = "$base_directory\src"
	$output_directory = "$base_directory\output"
	$packages_directory = "$src_directory\packages"
	$sln_file = "$src_directory\NEventStore.Persistence.RavenDB.sln"
	$target_config = "Release"
	$framework_version = "v4.0"
	$version = "0.0.0.0"

	$xunit_path = "$base_directory\bin\xunit.runners.1.9.1\tools\xunit.console.clr4.exe"
	$ilMergeModule.ilMergePath = "$base_directory\bin\ilmerge-bin\ILMerge.exe"
	$nuget_dir = "$src_directory\.nuget"

	if($runPersistenceTests -eq $null) {
		$runPersistenceTests = $false
	}
}

task default -depends Build

task Build -depends Clean, UpdateVersion, Compile, Test

task Clean {
	Clean-Item $publish_directory -ea SilentlyContinue
    Clean-Item $output_directory -ea SilentlyContinue
}

task UpdateVersion {
	$vSplit = $version.Split('.')
	if($vSplit.Length -ne 4)
	{
		throw "Version number is invalid. Must be in the form of 0.0.0.0"
	}
	$major = $vSplit[0]
	$minor = $vSplit[1]
	$assemblyFileVersion = $version
	$assemblyVersion = "$major.$minor.0.0"
	$versionAssemblyInfoFile = "$src_directory/VersionAssemblyInfo.cs"
	"using System.Reflection;" > $versionAssemblyInfoFile
	"" >> $versionAssemblyInfoFile
	"[assembly: AssemblyVersion(""$assemblyVersion"")]" >> $versionAssemblyInfoFile
	"[assembly: AssemblyFileVersion(""$assemblyFileVersion"")]" >> $versionAssemblyInfoFile
}

task Compile {
	EnsureDirectory $output_directory
	exec { msbuild /nologo /verbosity:quiet $sln_file /p:Configuration=$target_config /t:Clean }
	exec { msbuild /nologo /verbosity:quiet $sln_file /p:Configuration=$target_config /p:TargetFrameworkVersion=v4.0 }
}

task Test -precondition { $runPersistenceTests } {
	"Persistence Tests"
	EnsureDirectory $output_directory
	Invoke-XUnit -Path $src_directory -TestSpec '*Persistence.RavenDB.Tests.dll' `
    -SummaryPath $output_directory\persistence_tests.xml `
    -XUnitPath $xunit_path
}

task Package -depends Build {
	move $output_directory $publish_directory
    mkdir $publish_directory\plugins\persistence\raven | out-null
    copy "$src_directory\NEventStore.Persistence.RavenDB\bin\$target_config\NEventStore.Persistence.RavenDB.???" "$publish_directory\plugins\persistence\raven"
}

task NuGetPack -depends Package {
	gci -r -i *.nuspec "$nuget_dir" |% { .$nuget_dir\nuget.exe pack $_ -basepath $base_directory -o $publish_directory -version $version }
}

function EnsureDirectory {
	param($directory)

	if(!(test-path $directory))
	{
		mkdir $directory
	}
}