# Локальный сервер для index.html — Clipboard API работает только с http(s), не с file://
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 5173
$prefix = "http://127.0.0.1:$port/"

function Get-SafeFilePath {
  param([string]$Relative)
  $rel = ($Relative -replace "^/", "").Replace("/", [IO.Path]::DirectorySeparatorChar)
  if ([string]::IsNullOrWhiteSpace($rel)) { $rel = "index.html" }
  $rootN = [IO.Path]::GetFullPath($root)
  $full = [IO.Path]::GetFullPath([IO.Path]::Combine($rootN, $rel))
  $prefix = $rootN + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    return $null
  }
  return $full
}

function Get-MimeType {
  param([string]$Path)
  switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    ".html" { return "text/html; charset=utf-8" }
    ".css" { return "text/css; charset=utf-8" }
    ".js" { return "application/javascript; charset=utf-8" }
    ".json" { return "application/json; charset=utf-8" }
    ".svg" { return "image/svg+xml" }
    ".ico" { return "image/x-icon" }
    ".png" { return "image/png" }
    ".jpg" { return "image/jpeg" }
    ".jpeg" { return "image/jpeg" }
    ".webp" { return "image/webp" }
    default { return "application/octet-stream" }
  }
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
try {
  $listener.Start()
} catch {
  Write-Host "Не удалось запустить сервер на $prefix — порт занят или нужны права. Закройте другой сервер или смените `$port в скрипте."
  exit 1
}

Write-Host ""
Write-Host "  Страница:  $prefix"
Write-Host "  Папка:    $root"
Write-Host "  Стоп:     Ctrl+C"
Write-Host ""

try {
  Start-Process $prefix | Out-Null
} catch { }

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request
  $res = $ctx.Response
  try {
    $path = Get-SafeFilePath -Relative $req.Url.AbsolutePath
    if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
      $bytes = [IO.File]::ReadAllBytes($path)
      $res.StatusCode = 200
      $res.ContentType = Get-MimeType -Path $path
      $res.ContentLength64 = $bytes.LongLength
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $res.StatusCode = 404
      $msg = [Text.Encoding]::UTF8.GetBytes("404 — файл не найден")
      $res.ContentType = "text/plain; charset=utf-8"
      $res.ContentLength64 = $msg.LongLength
      $res.OutputStream.Write($msg, 0, $msg.Length)
    }
  } finally {
    $res.OutputStream.Close()
    $res.Close()
  }
}
