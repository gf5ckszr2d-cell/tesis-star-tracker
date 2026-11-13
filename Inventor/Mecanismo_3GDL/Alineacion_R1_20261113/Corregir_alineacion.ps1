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
public class AlignGimbal {
 dynamic app,tg,assembly; string root,cad; StringBuilder log=new StringBuilder();
 string N(double x){return x.ToString("G12",CultureInfo.InvariantCulture);}
 void L(string x){log.AppendLine(x);Console.WriteLine(x);File.WriteAllText(Path.Combine(root,"Control","correccion.txt"),log.ToString(),new UTF8Encoding(false));}
 string P(dynamic p){return N((double)p.X*10)+","+N((double)p.Y*10)+","+N((double)p.Z*10);}
 void MoveSketch(dynamic sketch,double x,double y,double z){
  dynamic origin=tg.CreatePoint(0,0,0),end=tg.CreatePoint(x/10,y/10,z/10);
  dynamic p=sketch.ModelToSketchSpace(origin),q=sketch.ModelToSketchSpace(end);
  dynamic objects=app.TransientObjects.CreateObjectCollection();
  foreach(dynamic e in sketch.SketchCircles){if(e.Reference)e.Reference=false;objects.Add(e);}
  L("MOVE_SKETCH="+sketch.Name+" ENTITIES="+objects.Count+" MODEL_DELTA_MM="+x+","+y+","+z);
  sketch.MoveSketchObjects(objects,tg.CreateVector2d((double)q.X-(double)p.X,(double)q.Y-(double)p.Y),false,true);
  sketch.Solve();
 }
 void CheckPart(dynamic d){
  if(!d.Update2(false))throw new Exception("Part update failed: "+d.DisplayName);
  if(d.ComponentDefinition.SurfaceBodies.Count!=1||!d.ComponentDefinition.SurfaceBodies[1].IsSolid)throw new Exception("Expected one solid");
  foreach(dynamic f in d.ComponentDefinition.Features)if((HealthStatusEnum)f.HealthStatus!=HealthStatusEnum.kUpToDateHealth)throw new Exception("Feature unhealthy "+f.Name);
  L("PART_OK="+d.DisplayName+" VOLUME_MM3="+N((double)d.ComponentDefinition.MassProperties.Volume*1000));
 }
 dynamic PlaneProxy(dynamic o,int index){object p;ComponentOccurrence occurrence=(ComponentOccurrence)o;PartComponentDefinition definition=(PartComponentDefinition)occurrence.Definition;WorkPlane plane=definition.WorkPlanes[index];occurrence.CreateGeometryProxy(plane,out p);return p;}
 void Build(){
  if(File.Exists(Path.Combine(cad,"Separador_pitch_0p8_R1.ipt")))throw new Exception("Revision already generated; do not rerun on completed CAD. Start from a fresh copy.");
  app=Activator.CreateInstance(Type.GetTypeFromProgID("Inventor.Application"));app.Visible=false;app.SilentOperation=true;tg=app.TransientGeometry;
  dynamic housing=app.Documents.Open(Path.Combine(cad,"cajita.ipt"),false);
  MoveSketch(housing.ComponentDefinition.Sketches.Item("Boceto2"),1.86269768833,.14993302131,0);
  MoveSketch(housing.ComponentDefinition.Sketches.Item("Boceto4"),1.86269768833,.14993302131,0);
  CheckPart(housing);housing.Save();housing.Close(true);
  string spacerPath=Path.Combine(cad,"Separador_pitch_0p8_R1.ipt");
  if(File.Exists(spacerPath))throw new Exception("Spacer already exists; use a fresh revision");
  dynamic spacer=app.Documents.Add(DocumentTypeEnum.kPartDocumentObject,app.FileManager.GetTemplateFile(DocumentTypeEnum.kPartDocumentObject),false);
  spacer.UnitsOfMeasure.LengthUnits=UnitsTypeEnum.kMillimeterLengthUnits;
  dynamic sk=spacer.ComponentDefinition.Sketches.Add(spacer.ComponentDefinition.WorkPlanes[3],false);
  sk.Name="Disco_20_centro_5p5_patron_14";
  sk.SketchCircles.AddByCenterRadius(tg.CreatePoint2d(0,0),1);
  sk.SketchCircles.AddByCenterRadius(tg.CreatePoint2d(0,0),.275);
  foreach(double[] xy in new double[][]{new double[]{.7,0},new double[]{0,.7},new double[]{-.7,0},new double[]{0,-.7}})sk.SketchCircles.AddByCenterRadius(tg.CreatePoint2d(xy[0],xy[1]),.15);
  dynamic extrusion=spacer.ComponentDefinition.Features.ExtrudeFeatures.AddByDistanceExtent(sk.Profiles.AddForSolid(true,Type.Missing,Type.Missing),"0.8 mm",PartFeatureExtentDirectionEnum.kNegativeExtentDirection,PartFeatureOperationEnum.kJoinOperation,Type.Missing);
  extrusion.Name="Separacion_axial_0p8_mm";sk.Visible=false;CheckPart(spacer);spacer.SaveAs(spacerPath,false);
  assembly=app.Documents.Open(Path.Combine(cad,"Gimbal_3GDL_alineado_R1.iam"),false);dynamic cd=assembly.ComponentDefinition;
  foreach(dynamic r in assembly.ReferencedDocumentDescriptors){if(r.ReferenceMissing||Path.GetDirectoryName((string)r.FullDocumentName)!=cad)throw new Exception("Reference outside revision: "+r.FullDocumentName);}
  cd.Occurrences.ItemByName("cajita:1").Grounded=false;
  foreach(dynamic c in cd.Constraints)if((ObjectTypeEnum)c.Type==ObjectTypeEnum.kAngleConstraintObject)c.Suppressed=false;
  dynamic offset=cd.Constraints.Item("Coincidencia:42");
  offset.Offset.Expression="0.8 mm";
  if(!assembly.Update2(false))throw new Exception("Assembly update failed first offset");
  double rollX=(double)cd.Constraints.Item("Coincidencia:40").GeometryOne.RootPoint.X*10;
  if(Math.Abs(rollX-10.15)>1e-5){offset.Offset.Expression="-0.8 mm";if(!assembly.Update2(false))throw new Exception("Assembly update failed reversed offset");}
  dynamic roll=cd.Constraints.Item("Coincidencia:40").GeometryOne;
  L("ROLL_AXIS_MM="+P(roll.RootPoint)+" OFFSET_EXPRESSION="+offset.Offset.Expression);
  if(Math.Abs((double)roll.RootPoint.X*10-10.15)>1e-5)throw new Exception("Roll does not meet yaw");
  dynamic horn=cd.Occurrences.ItemByName("Pieza6:2");dynamic spacerOcc=cd.Occurrences.Add(spacerPath,horn.Transformation);
  spacerOcc.Name="Separador pitch 0.8 mm";
  for(int i=1;i<=3;i++){dynamic c=cd.Constraints.AddFlushConstraint(PlaneProxy(spacerOcc,i),PlaneProxy(horn,i),"0 mm",Type.Missing,Type.Missing);c.Name="Separador_origen_"+i;}
  if(!assembly.Update2(false))throw new Exception("Assembly update failed spacer");
  foreach(dynamic c in cd.Constraints)if((HealthStatusEnum)c.HealthStatus!=HealthStatusEnum.kUpToDateHealth)throw new Exception("Constraint unhealthy "+c.Name+" "+c.HealthStatus);
  foreach(string name in new string[]{"Coincidencia:36","Coincidencia:38","Coincidencia:40"})L("AXIS="+name+" POINT_MM="+P(cd.Constraints.Item(name).GeometryOne.RootPoint));
  dynamic cam=cd.Occurrences.ItemByName("Camera OV7670:1");
  double lensX=0,lensY=0;bool found=false;
  foreach(dynamic body in cam.Definition.SurfaceBodies)foreach(dynamic face in body.Faces){
   if((SurfaceTypeEnum)face.SurfaceType!=SurfaceTypeEnum.kCylinderSurface)continue;
   dynamic g=face.Geometry;if(Math.Abs((double)g.Radius-.7)>1e-6)continue;
   dynamic point=g.BasePoint.Copy();point.TransformBy(cam.Transformation);
   dynamic v=g.AxisVector.Copy();v.TransformBy(cam.Transformation);
   L("LENS_AXIS_POINT_MM="+P(point)+" DIR="+N((double)v.X)+","+N((double)v.Y)+","+N((double)v.Z));
   lensX=point.X*10;lensY=point.Y*10;found=true;break;
  }
  if(!found||Math.Abs(lensX-10.15)>1e-5||Math.Abs(lensY-114.5)>1e-5)throw new Exception("Lens axis remains displaced");
  // Keep the received static reference posture; motion and screw engagement are separate checks.
  assembly.Save();spacer.Close(true);
  L("SAVED="+assembly.FullFileName);L("OCCURRENCES="+cd.Occurrences.Count+" CONSTRAINTS="+cd.Constraints.Count);
  dynamic all=app.TransientObjects.CreateObjectCollection();foreach(dynamic o in cd.Occurrences)all.Add(o);
  dynamic clashes=cd.AnalyzeInterference(all,Type.Missing);L("INTERFERENCE_COUNT="+clashes.Count);
  foreach(dynamic clash in clashes)L("INTERFERENCE="+clash.OccurrenceOne.Name+" / "+clash.OccurrenceTwo.Name+" VOLUME_MM3="+N((double)clash.Volume*1000));
  assembly.Close(true);assembly=null;L("ALIGNMENT_PASS=true");
 }
 public static void Run(string folder){var a=new AlignGimbal();a.root=folder;a.cad=Path.Combine(folder,"CAD");try{a.Build();}catch(Exception e){a.L("ERROR="+e.ToString());throw;}finally{if(a.assembly!=null)try{a.assembly.Close(true);}catch{}if(a.app!=null)try{a.app.Quit();}catch{}}}
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies $interop,'Microsoft.CSharp.dll','System.Core.dll'
[AlignGimbal]::Run($PSScriptRoot)
