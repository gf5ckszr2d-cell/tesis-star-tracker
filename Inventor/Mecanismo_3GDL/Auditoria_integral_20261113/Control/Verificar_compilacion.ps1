param([string]$Folder)
$ErrorActionPreference='Stop'
$interop='C:\Program Files\Autodesk\Inventor 2027\Bin\Public Assemblies\Autodesk.Inventor.Interop.dll'
[void][Reflection.Assembly]::LoadFrom($interop)
foreach($name in @('Auditar_gimbal.ps1','Mostrar_referencias.ps1')) {
 $tokens=$null;$parseErrors=$null
 $ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Folder $name),[ref]$tokens,[ref]$parseErrors)
 if($parseErrors.Count){throw $parseErrors}
 $blocks=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value.StartsWith('using System;')},$true)
 if($blocks.Count -ne 1){throw 'C# block missing'}
 Add-Type -TypeDefinition $blocks[0].Value -ReferencedAssemblies $interop,'Microsoft.CSharp.dll','System.Core.dll'
 Write-Output ('COMPILE_OK='+$name)
}