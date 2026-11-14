param([switch]$Choque)
$ErrorActionPreference='Stop'
$interop='C:\Program Files\Autodesk\Inventor 2027\Bin\Public Assemblies\Autodesk.Inventor.Interop.dll'
[void][Reflection.Assembly]::LoadFrom($interop)
$code=@'
using System;
using System.IO;
using System.Text;
using System.Globalization;
using System.Runtime.InteropServices;
using Inventor;
using Path=System.IO.Path;
using File=System.IO.File;
public class ShowAuditReferences {
 static string N(double x){return x.ToString("G12",CultureInfo.InvariantCulture);}
 static string P(dynamic p){return N((double)p.X*10)+","+N((double)p.Y*10)+","+N((double)p.Z*10);}
 public static void Run(string root,bool collision){
  dynamic app;try{app=Marshal.GetActiveObject("Inventor.Application");}catch{app=Activator.CreateInstance(Type.GetTypeFromProgID("Inventor.Application"));}
  app.SilentOperation=true;dynamic tg=app.TransientGeometry;
  dynamic d=app.Documents.Open(Path.Combine(root,"CAD","Gimbal_auditoria_con_ejes.iam"),true),cd=d.ComponentDefinition;
  dynamic reference=cd.Occurrences.ItemByName("REFERENCIAS_NO_FABRICAR").Definition.Document;
  double[] center={1.015,11.45,0};string[] names={"Y_YAW_REFERENCIA_CERO","X_PITCH_REFERENCIA_CERO","Z_ROLL_REFERENCIA_CERO"};
  double[][] dirs={new double[]{0,1,0},new double[]{1,0,0},new double[]{0,0,1}};byte[][] colors={new byte[]{90,230,90},new byte[]{255,100,90},new byte[]{70,180,255}};
  for(int k=0;k<3;k++){
   dynamic sk=null;foreach(dynamic old in reference.ComponentDefinition.Sketches3D)if(old.Name==names[k])sk=old;
   if(sk==null){sk=reference.ComponentDefinition.Sketches3D.Add();sk.Name=names[k];sk.SketchLines3D.AddByTwoPoints(tg.CreatePoint(center[0]-dirs[k][0]*10,center[1]-dirs[k][1]*10,center[2]-dirs[k][2]*10),tg.CreatePoint(center[0]+dirs[k][0]*10,center[1]+dirs[k][1]*10,center[2]+dirs[k][2]*10),false,Type.Missing);}
   sk.OverrideColor=app.TransientObjects.CreateColor(colors[k][0],colors[k][1],colors[k][2],1);sk.Visible=false;
  }
  foreach(dynamic sk in reference.ComponentDefinition.Sketches3D){if(((string)sk.Name).StartsWith("TRAYECTORIA_P_")){sk.Visible=!collision;sk.OverrideColor=app.TransientObjects.CreateColor(255,175,70,1);}if(sk.Name=="SEGMENTO_OP_DISTANCIA_NO_CERO"){sk.Visible=true;sk.OverrideColor=app.TransientObjects.CreateColor(255,230,0,1);}}
  reference.Save();foreach(dynamic ax in cd.WorkAxes)if(((string)ax.Name).StartsWith("EJE_"))ax.Visible=false;
  dynamic servoDoc=cd.Occurrences.ItemByName("Servo MG996R:1").Definition.Document,servoDef=servoDoc.ComponentDefinition,liveAxis=null;
  foreach(dynamic ax in servoDef.WorkAxes)if(ax.Name=="EJE_REAL_SALIDA_SERVO")liveAxis=ax;
  if(liveAxis==null)foreach(dynamic body in servoDef.SurfaceBodies)foreach(dynamic face in body.Faces){if((SurfaceTypeEnum)face.SurfaceType!=SurfaceTypeEnum.kCylinderSurface)continue;dynamic g=face.Geometry;if(Math.Abs((double)g.Radius-.359201549707)<1e-6&&Math.Abs((double)g.AxisVector.Y)>.99&&Math.Abs((double)g.BasePoint.X-1)<.02&&Math.Abs((double)g.BasePoint.Z+1)<.02){WorkAxes axes=(WorkAxes)servoDef.WorkAxes;liveAxis=axes.AddByRevolvedFace((Face)face,false);liveAxis.Name="EJE_REAL_SALIDA_SERVO";break;}}
  if(liveAxis==null)throw new Exception("No se encontró el cilindro de salida para su eje real");
  liveAxis.AutoResize=false;liveAxis.SetSize(tg.CreatePoint(1,-5,-1),tg.CreatePoint(1,15,-1));liveAxis.Visible=true;
  double servoVolume=(double)servoDef.MassProperties.Volume*1000;if(Math.Abs(servoVolume-31732.10533)>.001)throw new Exception("Cambió el volumen del servo al agregar referencias");servoDoc.Save();
  foreach(dynamic c in cd.Constraints)if((ObjectTypeEnum)c.Type==ObjectTypeEnum.kAngleConstraintObject){string first=c.OccurrenceOne.Name;c.Angle.Value=collision&&(first=="Base_Z:1"||first=="Base_Z:2")?-Math.PI/3:0;}
  if(!d.Update2(false))throw new Exception("Cannot update diagnostic pose");
  var s=new StringBuilder();s.AppendLine("POSE="+(collision?"yaw=-60,pitch=-60,roll=0":"zero"));
  foreach(dynamic o in cd.Occurrences)if(o.Name=="base:1"||o.Name=="Servo MG996R:3")s.AppendLine("BOUND="+o.Name+" MM="+P(o.RangeBox.MinPoint)+" -> "+P(o.RangeBox.MaxPoint));
  if(collision){dynamic set=app.TransientObjects.CreateObjectCollection();set.Add(cd.Occurrences.ItemByName("base:1"));set.Add(cd.Occurrences.ItemByName("Servo MG996R:1"));set.Add(cd.Occurrences.ItemByName("Servo MG996R:3"));foreach(dynamic clash in cd.AnalyzeInterference(set,Type.Missing))s.AppendLine("CLASH="+clash.OccurrenceOne.Name+" / "+clash.OccurrenceTwo.Name+" MM3="+N((double)clash.Volume*1000)+" BOUND_MM="+P(clash.InterferenceBody.RangeBox.MinPoint)+" -> "+P(clash.InterferenceBody.RangeBox.MaxPoint));}
  else{dynamic servo=cd.Occurrences.ItemByName("Servo MG996R:1");foreach(dynamic body in servo.Definition.SurfaceBodies)foreach(dynamic face in body.Faces){if((SurfaceTypeEnum)face.SurfaceType!=SurfaceTypeEnum.kCylinderSurface)continue;dynamic g=face.Geometry;if(Math.Abs((double)g.AxisVector.Y)>.99&&Math.Abs((double)g.BasePoint.X-1)<.02&&Math.Abs((double)g.BasePoint.Z+1)<.02)s.AppendLine("SERVO_SHAFT_R_MM="+N((double)g.Radius*10)+" LOCAL_POINT_MM="+P(g.BasePoint));}}
  app.Visible=true;app.WindowState=WindowsSizeEnum.kMaximize;d.Activate();d.SelectSet.Clear();dynamic view=app.ActiveView;view.DisplayMode=DisplayModeEnum.kShadedWithEdgesRendering;dynamic camera=view.Camera;
  camera.Perspective=false;camera.Eye=tg.CreatePoint(24,22,collision?-33:33);camera.Target=tg.CreatePoint(1.015,9,0);camera.UpVector=tg.CreateUnitVector(0,1,0);camera.ApplyWithoutTransition();camera.SetExtents(30,18);camera.ApplyWithoutTransition();view.Update();
  if(!collision)d.Save();
  File.WriteAllText(Path.Combine(root,"Control",collision?"detalle_choque.txt":"referencias_y_cabezal.txt"),s.ToString(),new UTF8Encoding(false));Console.WriteLine(s.ToString());
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies $interop,'Microsoft.CSharp.dll','System.Core.dll'
[ShowAuditReferences]::Run($PSScriptRoot,[bool]$Choque)
