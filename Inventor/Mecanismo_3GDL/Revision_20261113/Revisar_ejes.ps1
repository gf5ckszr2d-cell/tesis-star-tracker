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
public class MechanismAxes {
 static StringBuilder s=new StringBuilder();
 static string N(double x){return x.ToString("G12",CultureInfo.InvariantCulture);}
 static void L(string x){s.AppendLine(x);Console.WriteLine(x);}
 static string P(dynamic p){return N((double)p.X*10)+","+N((double)p.Y*10)+","+N((double)p.Z*10);}
 public static void Run(string root) {
  dynamic app=null,d=null;
  try {
   app=Activator.CreateInstance(Type.GetTypeFromProgID("Inventor.Application")); app.Visible=false;app.SilentOperation=true;
   d=app.Documents.Open(Path.Combine(root,"CAD_portable","mecanismo compoleto.iam"),false);
   dynamic cd=d.ComponentDefinition;
   dynamic camera=cd.Occurrences.ItemByName("Camera OV7670:1");
   foreach(dynamic body in camera.Definition.SurfaceBodies) foreach(dynamic face in body.Faces) {
    if((SurfaceTypeEnum)face.SurfaceType!=SurfaceTypeEnum.kCylinderSurface)continue;
    dynamic g=face.Geometry;
    double radius=g.Radius;
    if(radius<.3)continue;
    dynamic center=g.BasePoint.Copy();center.TransformBy(camera.Transformation);
    dynamic axis=g.AxisVector.Copy();axis.TransformBy(camera.Transformation);
    L("CAMERA_CYLINDER_RADIUS_MM="+N(radius*10)+" CENTER_MM="+P(center)+" AXIS="+N((double)axis.X)+","+N((double)axis.Y)+","+N((double)axis.Z));
   }
   L("EXPERIMENT=Unsaved in-memory mobility diagnostic only; no CAD file is written.");
   cd.Occurrences.ItemByName("cajita:1").Grounded=false;
   foreach(dynamic c in cd.Constraints) if((ObjectTypeEnum)c.Type==ObjectTypeEnum.kAngleConstraintObject)c.Suppressed=true;
   bool updated=d.Update2(false); L("UPDATED="+updated);
   foreach(string name in new string[]{"Base_Z:1","Base_Z:2","cajita:1"}) {
    var o=(ComponentOccurrence)cd.Occurrences.ItemByName(name);
    int nt,nr;ObjectsEnumerator tv,rv;Inventor.Point center;
    o.GetDegreesOfFreedom(out nt,out tv,out nr,out rv,out center);
    L("AFTER_RELEASE="+name+" TRANSLATIONS="+nt+" ROTATIONS="+nr);
   }
   L("NO_MOTION_SWEEP=true;SAVED=false");
  } finally {
   File.WriteAllText(Path.Combine(root,"Revision_20261113","revision_ejes.txt"),s.ToString(),new UTF8Encoding(false));
   if(d!=null)try{d.Close(true);}catch{}
   if(app!=null)try{app.Quit();}catch{}
  }
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies $interop,'Microsoft.CSharp.dll','System.Core.dll'
[MechanismAxes]::Run([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')))
