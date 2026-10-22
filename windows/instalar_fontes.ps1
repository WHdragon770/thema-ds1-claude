# instala as fontes da pasta fontes\ (Cinzel e Libertinus Mono, licença OFL) só pro usuário, sem precisar de admin
$dir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'; New-Item -ItemType Directory -Force -Path $dir | Out-Null
Add-Type -Namespace F -Name G -MemberDefinition '[DllImport("gdi32.dll")] public static extern int AddFontResource(string f); [DllImport("user32.dll")] public static extern int SendMessageTimeout(System.IntPtr h, int m, System.IntPtr w, System.IntPtr l, int f, int t, out System.IntPtr r);'
foreach ($f in Get-ChildItem (Join-Path $PSScriptRoot 'fontes') -Filter *.ttf) {
    $dst = Join-Path $dir $f.Name; Copy-Item $f.FullName $dst -Force
    $nome = ([System.IO.Path]::GetFileNameWithoutExtension($f.Name) -replace '-', ' ') + ' (TrueType)'
    New-ItemProperty 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' -Name $nome -Value $dst -PropertyType String -Force | Out-Null
    [void][F.G]::AddFontResource($dst)
}
$r = [IntPtr]::Zero; [void][F.G]::SendMessageTimeout([IntPtr]0xffff, 0x1D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$r)
'fontes instaladas'
