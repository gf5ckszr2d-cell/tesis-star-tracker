$ErrorActionPreference='Stop'
$interop='C:\Program Files\Autodesk\Inventor 2027\Bin\Public Assemblies\Autodesk.Inventor.Interop.dll'
[void][Reflection.Assembly]::LoadFrom($interop)
$code=@'
using System;
using System.Text;
using System.IO;
using System.Globalization;
using System.Runtime.InteropServices;
using Inventor;
public class ScreenshotProjection {
 public static void Run(string output){
  dynamic app=Marshal.GetActiveObject("Inventor.Application");dynamic view=app.ActiveView;dynamic tg=app.TransientGeometry;var s=new StringBuilder();
  s.AppendLine("VIEW_LEFT="+view.Left+" TOP="+view.Top+" WIDTH="+view.Width+" HEIGHT="+view.Height);
  foreach(double[] xyz in new double[][]{new double[]{1.015,11.45,0},new double[]{7.015,11.45,0},new double[]{1.015,17.45,0},new double[]{1.015,11.45,6}}){dynamic xy=view.Camera.ModelToViewSpace(tg.CreatePoint(xyz[0],xyz[1],xyz[2]));s.AppendLine(string.Format(CultureInfo.InvariantCulture,"POINT={0},{1},{2} SCREEN_XY={3},{4}",xyz[0]*10,xyz[1]*10,xyz[2]*10,(double)xy.X+(int)view.Left,(double)xy.Y+(int)view.Top));}
  System.IO.File.WriteAllText(output,s.ToString());Console.WriteLine(s.ToString());
 }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies $interop,'Microsoft.CSharp.dll','System.Core.dll'
[ScreenshotProjection]::Run((Join-Path $PSScriptRoot 'Control\proyeccion_captura.txt'))
