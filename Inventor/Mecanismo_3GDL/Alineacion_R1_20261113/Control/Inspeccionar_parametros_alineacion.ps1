$ErrorActionPreference='Stop'
$interop='C:\Program Files\Autodesk\Inventor 2027\Bin\Public Assemblies\Autodesk.Inventor.Interop.dll'
[void][Reflection.Assembly]::LoadFrom($interop)
$code=@'
using System;
using System.Text;
using System.IO;
using System.Globalization;
using Inventor;
using File=System.IO.File;
using Path=System.IO.Path;
public class AlignInspect {
 static StringBuilder s=new StringBuilder();
 static string N(double x){return x.ToString("G12",CultureInfo.InvariantCulture);}
 static void L(string x){s.AppendLine(x);}
 static string P(dynamic p){return N((double)p.X*10)+","+N((double)p.Y*10)+","+N((double)p.Z*10);}
 public static void Run(string root,string output) {
  dynamic app=null;
  try {
   app=Activator.CreateInstance(Type.GetTypeFromProgID("Inventor.Application"));app.Visible=false;app.SilentOperation=true;
   foreach(string name in new string[]{"Base_Z.ipt","cajita.ipt","Pieza6.ipt"}) {
    dynamic d=app.Documents.Open(Path.Combine(root,"CAD_portable",name),false);
    L("PART="+name);dynamic cd=d.ComponentDefinition;
    foreach(dynamic p in cd.Parameters) L(" PARAM="+p.Name+" EXPR="+p.Expression+" VALUE="+N((double)p.Value));
    foreach(dynamic f in cd.Features) L(" FEATURE="+f.Name+" TYPE="+f.Type+" HEALTH="+f.HealthStatus);
    foreach(dynamic sk in cd.Sketches){
     L(" SKETCH="+sk.Name+" HEALTH="+sk.HealthStatus);
     foreach(dynamic circle in sk.SketchCircles) L(" CIRCLE="+P(sk.SketchToModelSpace(circle.CenterSketchPoint.Geometry))+" R_MM="+N((double)circle.Radius*10));
     foreach(dynamic dim in sk.DimensionConstraints) L(" DIM="+dim.Type+" PARAM="+dim.Parameter.Name+" EXPR="+dim.Parameter.Expression);
    }
    foreach(dynamic body in cd.SurfaceBodies)foreach(dynamic face in body.Faces){
     if((SurfaceTypeEnum)face.SurfaceType==SurfaceTypeEnum.kCylinderSurface) {dynamic g=face.Geometry;L(" CYL_R_MM="+N((double)g.Radius*10)+" CENTER="+P(g.BasePoint)+" AX="+N((double)g.AxisVector.X)+","+N((double)g.AxisVector.Y)+","+N((double)g.AxisVector.Z));}
    }
    d.Close(true);
   }
  }finally{
   File.WriteAllText(Path.Combine(output,"parametros_para_alineacion.txt"),s.ToString(),new UTF8Encoding(false));
   if(app!=null)try{app.Quit();}catch{}
  }
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies $interop,'Microsoft.CSharp.dll','System.Core.dll'
[AlignInspect]::Run([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')),$PSScriptRoot)
