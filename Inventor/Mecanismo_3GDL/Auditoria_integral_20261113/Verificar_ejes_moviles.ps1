$ErrorActionPreference='Stop'
$interop='C:\Program Files\Autodesk\Inventor 2027\Bin\Public Assemblies\Autodesk.Inventor.Interop.dll'
[void][Reflection.Assembly]::LoadFrom($interop)
$code=@'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;
using Inventor;
public class VerifyMovingAxes {
 public static void Run(string root){
  dynamic app=Marshal.GetActiveObject("Inventor.Application"),d=null;
  foreach(dynamic candidate in app.Documents)if(candidate.FullFileName==System.IO.Path.Combine(root,"CAD","Gimbal_auditoria_con_ejes.iam"))d=candidate;
  if(d==null)throw new Exception("Audit assembly not open");
  dynamic cd=d.ComponentDefinition;var angles=new List<dynamic>();var initial=new List<double>();var log=new StringBuilder();
  foreach(dynamic c in cd.Constraints)if((ObjectTypeEnum)c.Type==ObjectTypeEnum.kAngleConstraintObject){angles.Add(c);initial.Add((double)c.Angle.Value);}
  try{
   foreach(bool moved in new bool[]{false,true}){
    foreach(dynamic c in angles){string first=c.OccurrenceOne.Name;c.Angle.Value=(moved?(first=="Base_Z:1"?20:first=="Base_Z:2"?30:15):0)*Math.PI/180;}
    if(!d.Update2(false))throw new Exception("Update failed");
    foreach(string name in new string[]{"Servo MG996R:1","Servo MG996R:2","Servo MG996R:3"}){
     ComponentOccurrence o=(ComponentOccurrence)cd.Occurrences.ItemByName(name);PartComponentDefinition def=(PartComponentDefinition)o.Definition;WorkAxis axis=def.WorkAxes["EJE_REAL_SALIDA_SERVO"];
     if(axis.DefinitionType!=WorkAxisDefinitionEnum.kRevolvedFaceWorkAxis)throw new Exception("Axis not bound to revolved face");
     object proxy;o.CreateGeometryProxy(axis,out proxy);dynamic line=((WorkAxisProxy)proxy).Line,p=line.RootPoint,v=line.Direction;
     double x=1.015-(double)p.X,y=11.45-(double)p.Y,z=-(double)p.Z;
     double a=y*(double)v.Z-z*(double)v.Y,b=z*(double)v.X-x*(double)v.Z,cross=x*(double)v.Y-y*(double)v.X;
     double miss=Math.Sqrt(a*a+b*b+cross*cross)*10;if(miss>1e-5)throw new Exception("Axis no longer passes through center");
     log.AppendLine(string.Format(CultureInfo.InvariantCulture,"MOVED={0} OCC={1} DIR={2:G12},{3:G12},{4:G12} CENTER_MISS_MM={5:G12}",moved,name,v.X,v.Y,v.Z,miss));
    }
   }
   log.AppendLine("LIVE_AXIS_BINDING_PASS=true");
  }finally{for(int i=0;i<angles.Count;i++)angles[i].Angle.Value=initial[i];d.Update2(false);d.Save();System.IO.File.WriteAllText(System.IO.Path.Combine(root,"Control","ejes_moviles_verificados.txt"),log.ToString());}
  Console.WriteLine(log.ToString());
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies $interop,'Microsoft.CSharp.dll','System.Core.dll'
[VerifyMovingAxes]::Run($PSScriptRoot)
