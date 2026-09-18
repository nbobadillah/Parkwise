# SmartParking

App de estacionamiento inteligente en SwiftUI (iOS 17+).

## Requisitos

- macOS con Xcode 16 o superior (App Store, gratis).

## Cómo abrir el proyecto

1. Clona o descarga este repositorio.
2. Abre `SmartParking.xcodeproj` con doble clic (está commiteado, no hace falta generar nada).
3. Arriba a la izquierda, junto al botón ▶️, elige un simulador de iPhone.
4. Dale a ▶️ (`⌘R`) para correr la app.

## Si necesitas regenerar el `.xcodeproj`

El proyecto se generó con [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partir de `project.yml`. Solo hace falta si vas a cambiar la estructura de targets/settings, no para trabajo normal de UI:

```bash
brew install xcodegen
cd SmartParking   # carpeta donde está project.yml
xcodegen generate
```

## Estructura

```
SmartParking/
  App/          punto de entrada (SmartParkingApp.swift)
  Design/       colores y estilos compartidos
  Models/       modelos de datos y datos de ejemplo
  Components/   piezas de UI reutilizables
  Views/        pantallas (Home, Mapa de parqueo, Root)
```

## Notas para el equipo

- No subas la carpeta `build/` ni `xcuserdata/` — ya están en `.gitignore`.
- El scheme `SmartParking` es compartido (`xcshareddata`), así que todos deberían verlo automáticamente al abrir el proyecto.
