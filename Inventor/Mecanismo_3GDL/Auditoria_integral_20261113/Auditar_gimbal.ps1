param([switch]$Barrido125)
$ErrorActionPreference='Stop'
$interop='C:\Program Files\Autodesk\Inventor 2027\Bin\Public Assemblies\Autodesk.Inventor.Interop.dll'
[void][Reflection.Assembly]::LoadFrom($interop)
$code=@'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Globalization;
using Inventor;
using File=System.IO.File;
using Path=System.IO.Path;
public class FullGimbalAudit {
 dynamic app,tg,d,cd,cam;string root,control;bool grid;StringBuilder log=new StringBuilder(),poses=new StringBuilder(),collisions=new StringBuilder();
 double[] center={1.015,11.45,0};dynamic pLocal,boardLocal;dynamic[] angle=new dynamic[3];
 List<double[]> yawPath=new List<double[]>(),pitchPath=new List<double[]>(),rollPath=new List<double[]>();
 string N(double v){return v.ToString("G12",CultureInfo.InvariantCulture);} string P(dynamic p){return N((double)p.X*10)+","+N((double)p.Y*10)+","+N((double)p.Z*10);}
 void L(string s){log.AppendLine(s);Console.WriteLine(s);File.WriteAllText(Path.Combine(control,"auditoria.txt"),log.ToString(),new UTF8Encoding(false));}
 double Dist(dynamic a,dynamic b){return Math.Sqrt(Math.Pow((double)a.X-(double)b.X,2)+Math.Pow((double)a.Y-(double)b.Y,2)+Math.Pow((double)a.Z-(double)b.Z,2))*10;}
 dynamic World(dynamic local){dynamic p=local.Copy();p.TransformBy(cam.Transformation);return p;}
 double CenterDistance(dynamic line){dynamic c=tg.CreatePoint(center[0],center[1],center[2]);dynamic v=line.Direction;double dx=(double)c.X-(double)line.RootPoint.X,dy=(double)c.Y-(double)line.RootPoint.Y,dz=(double)c.Z-(double)line.RootPoint.Z;double x=dy*(double)v.Z-dz*(double)v.Y,y=dz*(double)v.X-dx*(double)v.Z,z=dx*(double)v.Y-dy*(double)v.X;return Math.Sqrt(x*x+y*y+z*z)*10;}
 dynamic StructuralSet(){dynamic all=app.TransientObjects.CreateObjectCollection();foreach(dynamic o in cd.Occurrences)if(!((string)o.Name).StartsWith("210212-"))all.Add(o);return all;}
 void SetAngles(double y,double p,double r){angle[0].Angle.Value=y*Math.PI/180;angle[1].Angle.Value=p*Math.PI/180;angle[2].Angle.Value=r*Math.PI/180;}
 bool Pose(string name,double y,double p,double r,bool check){
  try{
   SetAngles(0,0,0);if(!d.Update2(false))throw new Exception("reset_failed");SetAngles(y,p,r);
   if(!d.Update2(false))throw new Exception("pose_update_failed");
   foreach(dynamic c in cd.Constraints)if((HealthStatusEnum)c.HealthStatus!=HealthStatusEnum.kUpToDateHealth)throw new Exception("constraint_"+c.Name+"_"+c.HealthStatus);
   double max=0;foreach(string key in new string[]{"Coincidencia:36","Coincidencia:38","Coincidencia:40"})max=Math.Max(max,CenterDistance(cd.Constraints.Item(key).GeometryOne));
   dynamic point=World(pLocal),board=World(boardLocal);dynamic p0=tg.CreatePoint(1.015,11.45,.836551218215),b0=tg.CreatePoint(1.015,11.45,-.15);
   // R1 places the mechanical center at camera-local (0, 4.5, 1.5) mm.
   dynamic anchor=World(tg.CreatePoint(0,.45,.15));
   double movedCenter=Dist(anchor,tg.CreatePoint(center[0],center[1],center[2]));
   double[] xyz={(double)point.X,(double)point.Y,(double)point.Z};
   if(name.StartsWith("yaw_"))yawPath.Add(xyz);if(name.StartsWith("pitch_"))pitchPath.Add(xyz);if(name.StartsWith("roll_"))rollPath.Add(xyz);
   int physical=0;if(check){dynamic clashes=cd.AnalyzeInterference(StructuralSet(),Type.Missing);foreach(dynamic clash in clashes){string a=clash.OccurrenceOne.Name,b=clash.OccurrenceTwo.Name;double volume=(double)clash.Volume*1000;bool known=((a.StartsWith("Servo MG996R")&&b.StartsWith("Pieza6"))||(b.StartsWith("Servo MG996R")&&a.StartsWith("Pieza6")))&&a.Substring(a.LastIndexOf(':' )+1)==b.Substring(b.LastIndexOf(':' )+1);collisions.AppendLine(name+","+a+","+b+","+N(volume)+","+(known?"servo_head_model_pending":"review"));if(!known&&volume>.001)physical++;}}
   poses.AppendLine(name+","+N(y)+","+N(p)+","+N(r)+",ok,"+P(point)+","+N(Dist(point,p0))+","+N(Dist(board,b0))+","+N(movedCenter)+","+N(max)+","+physical);
   L("POSE="+name+" P_MM="+P(point)+" P_DISPLACEMENT_MM="+N(Dist(point,p0))+" O_DISPLACEMENT_MM="+N(movedCenter)+" MAX_AXIS_MISS_MM="+N(max)+" REVIEW_CLASHES="+physical);
   return true;
  }catch(Exception e){poses.AppendLine(name+","+N(y)+","+N(p)+","+N(r)+",failed,,,,,,,,");L("POSE_FAIL="+name+" "+e.Message);try{SetAngles(0,0,0);d.Update2(false);}catch{}return false;}
  finally{File.WriteAllText(Path.Combine(control,"poses.csv"),poses.ToString());File.WriteAllText(Path.Combine(control,"interferencias_movimiento.csv"),collisions.ToString());}
 }
 dynamic RefPoint(string name,double x,double y,double z,bool visible){dynamic p=cd.WorkPoints.AddFixed(tg.CreatePoint(x,y,z),false);p.Name=name;p.Visible=visible;return p;}
 void Line(dynamic sketch,double[] a,double[] b){if(Math.Abs(a[0]-b[0])+Math.Abs(a[1]-b[1])+Math.Abs(a[2]-b[2])<1e-8)return;dynamic l=sketch.SketchLines3D.AddByTwoPoints(tg.CreatePoint(a[0],a[1],a[2]),tg.CreatePoint(b[0],b[1],b[2]),false,Type.Missing);}
 void VisualRefs(){
  RefPoint("O_CENTRO_MECANICO_NO_PUPILA_MEDIDA",center[0],center[1],center[2],true);
  RefPoint("P_BARRIL_REFERENCIA_GEOMETRICA",center[0],center[1],.836551218215,true);
  RefPoint("S_PLANO_PCB_NO_SENSOR_MEDIDO",center[0],center[1],-.15,true);
  double[][] dirs={new double[]{0,1,0},new double[]{1,0,0},new double[]{0,0,1}};
  string[] names={"EJE_1_YAW_CERO","EJE_2_PITCH_CERO","EJE_3_ROLL_CERO"};
  for(int k=0;k<3;k++){dynamic axis=cd.WorkAxes.AddFixed(tg.CreatePoint(center[0],center[1],center[2]),tg.CreateUnitVector(dirs[k][0],dirs[k][1],dirs[k][2]),false);axis.Name=names[k];axis.Visible=true;}
  dynamic reference=app.Documents.Add(DocumentTypeEnum.kPartDocumentObject,app.FileManager.GetTemplateFile(DocumentTypeEnum.kPartDocumentObject),false);
  dynamic segment=reference.ComponentDefinition.Sketches3D.Add();segment.Name="SEGMENTO_OP_DISTANCIA_NO_CERO";Line(segment,center,new double[]{center[0],center[1],.836551218215});segment.Visible=true;
  int n=0;foreach(List<double[]> path in new List<double[]>[]{yawPath,pitchPath,rollPath}){dynamic sketch=reference.ComponentDefinition.Sketches3D.Add();sketch.Name=new string[]{"TRAYECTORIA_P_YAW","TRAYECTORIA_P_PITCH","TRAYECTORIA_P_ROLL"}[n++];for(int i=1;i<path.Count;i++)Line(sketch,path[i-1],path[i]);sketch.Visible=(n<3);}
  string referencePath=Path.Combine(root,"CAD","Referencias_cinematicas.ipt");reference.SaveAs(referencePath,false);
  dynamic occurrence=cd.Occurrences.Add(referencePath,tg.CreateMatrix());occurrence.Name="REFERENCIAS_NO_FABRICAR";occurrence.Grounded=true;occurrence.BOMStructure=BOMStructureEnum.kReferenceBOMStructure;
 }
 void RunAudit(){
  app=Activator.CreateInstance(Type.GetTypeFromProgID("Inventor.Application"));app.Visible=false;app.SilentOperation=true;tg=app.TransientGeometry;
  d=app.Documents.Open(Path.Combine(root,"CAD",grid?"Gimbal_barrido_125.iam":"Gimbal_auditoria_con_ejes.iam"),false);cd=d.ComponentDefinition;cam=cd.Occurrences.ItemByName("Camera OV7670:1");
  foreach(dynamic r in d.ReferencedDocumentDescriptors) {L("REFERENCE="+r.FullDocumentName+" MISSING="+r.ReferenceMissing);if(r.ReferenceMissing||Path.GetDirectoryName((string)r.FullDocumentName)!=Path.Combine(root,"CAD"))throw new Exception("Bad reference");}
  var documents=new HashSet<string>();
  foreach(dynamic o in cd.Occurrences){dynamic part=o.Definition.Document;if(!documents.Add((string)part.FullFileName))continue;dynamic def=part.ComponentDefinition;L("PART="+part.DisplayName+" SOLIDS="+def.SurfaceBodies.Count+" MATERIAL="+part.ActiveMaterial.DisplayName+" VOLUME_MM3="+N((double)def.MassProperties.Volume*1000));foreach(dynamic f in def.Features)if((HealthStatusEnum)f.HealthStatus!=HealthStatusEnum.kUpToDateHealth)L("FEATURE_PROBLEM="+part.DisplayName+"/"+f.Name+" "+f.HealthStatus);}
  foreach(dynamic body in cam.Definition.SurfaceBodies)foreach(dynamic face in body.Faces){if((SurfaceTypeEnum)face.SurfaceType!=SurfaceTypeEnum.kCylinderSurface)continue;dynamic g=face.Geometry;if(Math.Abs((double)g.Radius-.7)<1e-6){pLocal=g.BasePoint.Copy();L("BARREL_LOCAL_POINT_MM="+P(pLocal));break;}}
  boardLocal=tg.CreatePoint(0,.45,0);
  dynamic servo=cd.Occurrences.ItemByName("Servo MG996R:1");foreach(dynamic body in servo.Definition.SurfaceBodies)foreach(dynamic face in body.Faces){if((SurfaceTypeEnum)face.SurfaceType!=SurfaceTypeEnum.kCylinderSurface)continue;dynamic g=face.Geometry;if(Math.Abs((double)g.AxisVector.Y)>.99&&Math.Abs((double)g.BasePoint.X-1)<.02&&Math.Abs((double)g.BasePoint.Z-1)<.02)L("SERVO_OUTPUT_CYLINDER_R_MM="+N((double)g.Radius*10)+" BASE_LOCAL_MM="+P(g.BasePoint));}
  var angles=new List<dynamic>();foreach(dynamic c in cd.Constraints)if((ObjectTypeEnum)c.Type==ObjectTypeEnum.kAngleConstraintObject){L("ANGLE="+c.Name+" FIRST="+c.OccurrenceOne.Name+" SECOND="+c.OccurrenceTwo.Name+" SOLUTION="+c.SolutionType);angles.Add(c);}
  foreach(dynamic a in angles){string first=a.OccurrenceOne.Name,second=a.OccurrenceTwo.Name;if(first=="Base_Z:1"||second=="base:1")angle[0]=a;else if(first=="Base_Z:2")angle[1]=a;else if(first=="cajita:1")angle[2]=a;}
  poses.AppendLine("pose,yaw_command_deg,pitch_command_deg,roll_command_deg,status,P_x_mm,P_y_mm,P_z_mm,P_displacement_mm,S_displacement_mm,O_displacement_mm,max_axis_miss_mm,review_clashes");
  collisions.AppendLine("pose,component_a,component_b,volume_mm3,class");
  if(grid){foreach(double y in new double[]{-60,-30,0,30,60})foreach(double p in new double[]{-60,-30,0,30,60})foreach(double r in new double[]{-60,-30,0,30,60})Pose("grid_"+N(y)+"_"+N(p)+"_"+N(r),y,p,r,true);}
  else{
  Pose("zero",0,0,0,true);
  foreach(double a in new double[]{-60,-30,-15,15,30,60})Pose("yaw_"+N(a),a,0,0,true);
  foreach(double a in new double[]{-60,-30,-15,15,30,60})Pose("pitch_"+N(a),0,a,0,true);
  foreach(double a in new double[]{-60,-30,-15,15,30,60})Pose("roll_"+N(a),0,0,a,true);
  Pose("combined_15",15,15,15,true);Pose("combined_30",30,30,30,true);Pose("combined_mixed",-30,30,-30,true);
  }
  SetAngles(0,0,0);if(!d.Update2(false))throw new Exception("Cannot restore zero");
  if(!grid){VisualRefs();d.Save();L("SAVED_DIAGNOSTIC_ASSEMBLY="+d.FullFileName);}d.Close(true);d=null;L("AUDIT_COMPLETE=true");
 }
 public static void Run(string root,bool grid){var a=new FullGimbalAudit();a.root=root;a.grid=grid;a.control=Path.Combine(root,"Control",grid?"Barrido125":"");Directory.CreateDirectory(a.control);try{a.RunAudit();}catch(Exception e){a.L("FATAL="+e.ToString());throw;}finally{if(a.d!=null)try{a.d.Close(true);}catch{}if(a.app!=null)try{a.app.Quit();}catch{}}}
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies $interop,'Microsoft.CSharp.dll','System.Core.dll'
[FullGimbalAudit]::Run($PSScriptRoot,[bool]$Barrido125)
