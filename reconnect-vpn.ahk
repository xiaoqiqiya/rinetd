; reconnect-vpn.ahk
Run, "C:\Program Files\Fortinet\FortiClient\FortiClientConsole.exe"
Sleep, 5000

; Asume que el perfil de VPN ya está preconfigurado y seleccionado
; Envía credenciales
Send, {Tab}
Send, {Tab}
Send, {Tab}
Send, USUARIOVPN
Send, {Tab}
Send, PASSWORDVPN
Send, {Enter}

; Opcional: cerrar ventana despues de conectar
; Sleep, 10000
; Send, !{F4}  ; Alt + F4
