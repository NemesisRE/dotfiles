# Print $env:PATH, one entry per line.
function path {
  $env:PATH -split [IO.Path]::PathSeparator
}
