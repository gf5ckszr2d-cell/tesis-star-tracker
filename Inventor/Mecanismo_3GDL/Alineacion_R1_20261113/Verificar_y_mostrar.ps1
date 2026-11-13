$ErrorActionPreference='Stop'
$interop='C:\Program Files\Autodesk\Inventor 2027\Bin\Public Assemblies\Autodesk.Inventor.Interop.dll'
[void][Reflection.Assembly]::LoadFrom($interop)
$code=@'
using System;
using System.IO;
using System.Text;
using System.Globalization;
using Inventor;
using Path=System.IO.Path;
using File=System.IO.File;
public class VerifyShow {
 static string N(double x){return x.ToString("G12",CultureInfo.InvariantCulture);}
 static string P(dynamic p){return N((double)p.X*10)+","+N((double)p.Y*10)+","+N((double)p.Z*10);}
 public static void Run(string root){
  var s=new StringBuilder();string cad=Path.Combine(root,"CAD");
  dynamic app=Activator.CreateInstance(Type.GetTypeFromProgID("Inventor.Application"));app.SilentOperation=true;
  dynamic d=app.Documents.Open(Path.Combine(cad,"Gimbal_3GDL_alineado_R1.iam"),true);dynamic cd=d.ComponentDefinition;
  foreach(dynamic r in d.ReferencedDocumentDescriptors){if(r.ReferenceMissing||Path.GetDirectoryName((string)r.FullDocumentName)!=cad)throw new Exception("Unresolved/nonlocal reference "+r.FullDocumentName);s.AppendLine("REFERENCE="+r.FullDocumentName);}
  if(!d.Update2(false))throw new Exception("Saved assembly cannot update");
  foreach(dynamic c in cd.Constraints)if((HealthStatusEnum)c.HealthStatus!=HealthStatusEnum.kUpToDateHealth)throw new Exception("Constraint unhealthy "+c.Name);
  foreach(string name in new string[]{"Coincidencia:36","Coincidencia:38","Coincidencia:40"}){
   dynamic a=cd.Constraints.Item(name).GeometryOne;
   s.AppendLine("AXIS="+name+" POINT_MM="+P(a.RootPoint)+" DIR="+N((double)a.Direction.X)+","+N((double)a.Direction.Y)+","+N((double)a.Direction.Z));
  }
  dynamic o=cd.Occurrences.ItemByName("Camera OV7670:1");
  foreach(dynamic body in o.Definition.SurfaceBodies)foreach(dynamic f in body.Faces){
   if((SurfaceTypeEnum)f.SurfaceType!=SurfaceTypeEnum.kCylinderSurface)continue;dynamic g=f.Geometry;if(Math.Abs((double)g.Radius-.7)>1e-6)continue;
   dynamic p=g.BasePoint.Copy();p.TransformBy(o.Transformation);dynamic v=g.AxisVector.Copy();v.TransformBy(o.Transformation);
   s.AppendLine("LENS_POINT_MM="+P(p)+" DIR="+N((double)v.X)+","+N((double)v.Y)+","+N((double)v.Z));
   if(Math.Abs((double)p.X*10-10.15)>1e-5||Math.Abs((double)p.Y*10-114.5)>1e-5)throw new Exception("Lens axis mismatch");
  }
  app.Visible=true;app.WindowState=WindowsSizeEnum.kMaximize;d.Activate();
  dynamic tg=app.TransientGeometry;dynamic view=app.ActiveView;dynamic camera=view.Camera;
  view.DisplayMode=DisplayModeEnum.kShadedWithEdgesRendering;
  camera.Perspective=false;camera.Eye=tg.CreatePoint(24,22,33);camera.Target=tg.CreatePoint(0,7,0);camera.UpVector=tg.CreateUnitVector(0,1,0);camera.ApplyWithoutTransition();camera.Fit();camera.ApplyWithoutTransition();view.Update();
  s.AppendLine("VIEW_LEFT="+view.Left+" TOP="+view.Top+" WIDTH="+view.Width+" HEIGHT="+view.Height);
  foreach(double[] xyz in new double[][]{new double[]{1.015,11.45,0},new double[]{7.015,11.45,0},new double[]{1.015,17.45,0},new double[]{1.015,11.45,6}}){
   dynamic xy=camera.ModelToViewSpace(tg.CreatePoint(xyz[0],xyz[1],xyz[2]));
   s.AppendLine("PROJECTED_MODEL_MM="+N(xyz[0]*10)+","+N(xyz[1]*10)+","+N(xyz[2]*10)+" VIEW_XY="+N((double)xy.X)+","+N((double)xy.Y));
  }
  d.Save();s.AppendLine("REOPEN_VERIFIED=true;SCREENSHOT_SOURCE=live Inventor;CAD_ALIGNMENT_ONLY=true");
  File.WriteAllText(Path.Combine(root,"Control","verificacion_reapertura_y_vista.txt"),s.ToString(),new UTF8Encoding(false));
  Console.WriteLine(s.ToString());
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies $interop,'Microsoft.CSharp.dll','System.Core.dll'
[VerifyShow]::Run($PSScriptRoot)
