#include "include/serial_com/serial_com_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "serial_com_plugin.h"

void SerialComPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  serial_com::SerialComPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
