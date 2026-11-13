param([string]$Ensamblaje = (Join-Path $PSScriptRoot '..\Original\mecanismo compoleto.iam'), [string]$Salida = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
$interop = 'C:\Program Files\Autodesk\Inventor 2027\Bin\Public Assemblies\Autodesk.Inventor.Interop.dll'
[void][Reflection.Assembly]::LoadFrom($interop)
$code = @'
using System;
using System.IO;
using Path=System.IO.Path;
using File=System.IO.File;
using System.Text;
using System.Globalization;
using System.Runtime.InteropServices;
using Inventor;
public class InspectMechanism {
 static StringBuilder log = new StringBuilder();
 static string F(double v) { return v.ToString("G12", CultureInfo.InvariantCulture); }
 static string P(dynamic p) { return F((double)p.X*10)+","+F((double)p.Y*10)+","+F((double)p.Z*10); }
 static void L(string s) { log.AppendLine(s); Console.WriteLine(s); }
 public static void Run(string input,string folder) {
  dynamic app = null, doc = null;
  try {
   app=Activator.CreateInstance(Type.GetTypeFromProgID("Inventor.Application"));
   app.Visible=false; app.SilentOperation=true;
   L("APP="+app.SoftwareVersion.DisplayVersion);
   doc=app.Documents.Open(Path.GetFullPath(input),false);
   L("DOCUMENT="+doc.FullFileName); L("DIRTY_ON_OPEN="+doc.Dirty);
   foreach(dynamic reference in doc.ReferencedDocumentDescriptors) {
    L("REFERENCE="+reference.FullDocumentName+" MISSING="+reference.ReferenceMissing);
   }
   dynamic cd=doc.ComponentDefinition;
   L("ASSEMBLY_BOUND_MM="+P(cd.RangeBox.MinPoint)+" -> "+P(cd.RangeBox.MaxPoint));
   L("OCCURRENCES="+cd.Occurrences.Count+" CONSTRAINTS="+cd.Constraints.Count+" JOINTS="+cd.Joints.Count);
   foreach(dynamic o in cd.Occurrences) {
    L("OCC="+o.Name+" GROUNDED="+o.Grounded+" SUPPRESSED="+o.Suppressed);
    try {
     L(" FILE="+o.Definition.Document.FullFileName+" BOUND_MM="+P(o.RangeBox.MinPoint)+" -> "+P(o.RangeBox.MaxPoint));
     dynamic t=o.Transformation;
     L(" TRANSFORM="+F(t.Cell[1,1])+","+F(t.Cell[1,2])+","+F(t.Cell[1,3])+","+F(t.Cell[1,4]*10)+";"+F(t.Cell[2,1])+","+F(t.Cell[2,2])+","+F(t.Cell[2,3])+","+F(t.Cell[2,4]*10)+";"+F(t.Cell[3,1])+","+F(t.Cell[3,2])+","+F(t.Cell[3,3])+","+F(t.Cell[3,4]*10));
     int nt=0,nr=0; Inventor.ObjectsEnumerator tv=null,rv=null; Inventor.Point center=null;
     ((ComponentOccurrence)o).GetDegreesOfFreedom(out nt,out tv,out nr,out rv,out center);
     L(" DOF_TRANSLATIONS="+nt+" ROTATIONS="+nr+" CENTER_MM="+P(center));
     if(rv!=null) foreach(dynamic v in rv) L(" ROT_VECTOR="+F((double)v.X)+","+F((double)v.Y)+","+F((double)v.Z));
    } catch(Exception e) { L(" OCC_ERROR="+e.Message); }
   }
   foreach(dynamic c in cd.Constraints) {
    string detail="";
    try { detail+=" FIRST="+c.OccurrenceOne.Name; } catch {}
    try { detail+=" SECOND="+c.OccurrenceTwo.Name; } catch {}
    try { detail+=" AXIS="+P(c.GeometryOne.RootPoint)+" DIR="+F((double)c.GeometryOne.Direction.X)+","+F((double)c.GeometryOne.Direction.Y)+","+F((double)c.GeometryOne.Direction.Z); } catch {}
    try { detail+=" ANGLE_RAD="+F((double)c.Angle.Value); } catch {}
    L("CONSTRAINT="+c.Name+" TYPE="+c.Type+" HEALTH="+((HealthStatusEnum)c.HealthStatus).ToString()+detail);
   }
   try {
    dynamic all=app.TransientObjects.CreateObjectCollection();
    foreach(dynamic o in cd.Occurrences) if(!o.Suppressed) all.Add(o);
    dynamic clashes=cd.AnalyzeInterference(all,Type.Missing);
    L("INTERFERENCE_COUNT="+clashes.Count);
    foreach(dynamic clash in clashes) L("INTERFERENCE="+clash.OccurrenceOne.Name+" / "+clash.OccurrenceTwo.Name+" VOLUME_MM3="+F((double)clash.Volume*1000));
   } catch(Exception e) { L("INTERFERENCE_ERROR="+e.Message); }
   L("VISUAL_EVIDENCE=Original PLANITOS.pdf; offscreen rendering excluded after visual rejection.");
   L("SAVED=false");
  } catch(Exception e) { L("FATAL="+e.ToString()); throw; }
  finally {
   File.WriteAllText(Path.Combine(folder,"inspeccion_CAD.txt"),log.ToString(),new UTF8Encoding(false));
   if(doc!=null) try { doc.Close(true); } catch {}
   if(app!=null) try { app.Quit(); } catch {}
  }
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies $interop,'Microsoft.CSharp.dll','System.Core.dll'
[InspectMechanism]::Run($Ensamblaje,$Salida)
