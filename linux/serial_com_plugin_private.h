#include <flutter_linux/flutter_linux.h>

#include "include/serial_com/serial_com_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

// Handles the getPlatformVersion method call.
FlMethodResponse *get_platform_version();

// New functions for serial communication
FlMethodResponse* handle_open_port(FlMethodCall* method_call);
FlMethodResponse* handle_close_port(FlMethodCall* method_call);
FlMethodResponse* handle_write_to_port(FlMethodCall* method_call);
FlMethodResponse* handle_read_from_port(FlMethodCall* method_call);
