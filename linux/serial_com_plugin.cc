#include "include/serial_com/serial_com_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>
#include <errno.h>

#include <cstring>

#include "serial_com_plugin_private.h"

#define SERIAL_COM_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), serial_com_plugin_get_type(), \
                              SerialComPlugin))

struct _SerialComPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(SerialComPlugin, serial_com_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void serial_com_plugin_handle_method_call(
    SerialComPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "openPort") == 0) {
    response = handle_open_port(method_call);
  } else if (strcmp(method, "closePort") == 0) {
    response = handle_close_port(method_call);
  } else if (strcmp(method, "writeToPort") == 0) {
    response = handle_write_to_port(method_call);
  } else if (strcmp(method, "readFromPort") == 0) {
    response = handle_read_from_port(method_call);
  } else if (strcmp(method, "requestPermission") == 0) {
    response = handle_request_permission(method_call);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void serial_com_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(serial_com_plugin_parent_class)->dispose(object);
}

static void serial_com_plugin_class_init(SerialComPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = serial_com_plugin_dispose;
}

static void serial_com_plugin_init(SerialComPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  SerialComPlugin* plugin = SERIAL_COM_PLUGIN(user_data);
  serial_com_plugin_handle_method_call(plugin, method_call);
}

void serial_com_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  SerialComPlugin* plugin = SERIAL_COM_PLUGIN(
      g_object_new(serial_com_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "serial_com",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}

// New functions for serial communication

FlMethodResponse* handle_open_port(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  const char* port_name = fl_value_get_string(fl_value_lookup_string(args, "port"));
  int baud_rate = fl_value_get_int(fl_value_lookup_string(args, "baudRate"));

  int fd = open(port_name, O_RDWR | O_NOCTTY | O_SYNC);
  if (fd < 0) {
    g_autofree gchar *error_msg = g_strdup_printf("Error opening port: %s", strerror(errno));
    return FL_METHOD_RESPONSE(fl_method_error_response_new("OPEN_ERROR", error_msg, nullptr));
  }

  struct termios tty;
  memset(&tty, 0, sizeof tty);
  if (tcgetattr(fd, &tty) != 0) {
    close(fd);
    return FL_METHOD_RESPONSE(fl_method_error_response_new("CONFIG_ERROR", "Error from tcgetattr", nullptr));
  }

  cfsetospeed(&tty, baud_rate);
  cfsetispeed(&tty, baud_rate);

  tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;
  tty.c_iflag &= ~IGNBRK;
  tty.c_lflag = 0;
  tty.c_oflag = 0;
  tty.c_cc[VMIN]  = 0;
  tty.c_cc[VTIME] = 5;

  tty.c_iflag &= ~(IXON | IXOFF | IXANY);
  tty.c_cflag |= (CLOCAL | CREAD);

  if (tcsetattr(fd, TCSANOW, &tty) != 0) {
    close(fd);
    return FL_METHOD_RESPONSE(fl_method_error_response_new("CONFIG_ERROR", "Error from tcsetattr", nullptr));
  }

  g_autoptr(FlValue) result = fl_value_new_int(fd);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* handle_close_port(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  int fd = fl_value_get_int(fl_value_lookup_string(args, "fd"));

  if (close(fd) < 0) {
    g_autofree gchar *error_msg = g_strdup_printf("Error closing port: %s", strerror(errno));
    return FL_METHOD_RESPONSE(fl_method_error_response_new("CLOSE_ERROR", error_msg, nullptr));
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* handle_write_to_port(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  int fd = fl_value_get_int(fl_value_lookup_string(args, "fd"));
  const char* data = fl_value_get_string(fl_value_lookup_string(args, "data"));

  ssize_t bytes_written = write(fd, data, strlen(data));
  if (bytes_written < 0) {
    g_autofree gchar *error_msg = g_strdup_printf("Error writing to port: %s", strerror(errno));
    return FL_METHOD_RESPONSE(fl_method_error_response_new("WRITE_ERROR", error_msg, nullptr));
  }

  g_autoptr(FlValue) result = fl_value_new_int(bytes_written);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* handle_read_from_port(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  int fd = fl_value_get_int(fl_value_lookup_string(args, "fd"));
  int max_length = fl_value_get_int(fl_value_lookup_string(args, "maxLength"));

  char* buffer = (char*)malloc(max_length + 1);
  ssize_t bytes_read = read(fd, buffer, max_length);
  if (bytes_read < 0) {
    free(buffer);
    g_autofree gchar *error_msg = g_strdup_printf("Error reading from port: %s", strerror(errno));
    return FL_METHOD_RESPONSE(fl_method_error_response_new("READ_ERROR", error_msg, nullptr));
  }

  buffer[bytes_read] = '\0';
  g_autoptr(FlValue) result = fl_value_new_string(buffer);
  free(buffer);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* handle_request_permission(FlMethodCall* method_call) {
  // On Linux, we don't typically need to request permission for serial ports.
  // Instead, we can check if the user has access to the serial port.
  
  FlValue* args = fl_method_call_get_args(method_call);
  const char* port_name = fl_value_get_string(fl_value_lookup_string(args, "port"));

  // Check if the port exists and is accessible
  if (access(port_name, R_OK | W_OK) == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    g_autofree gchar *error_msg = g_strdup_printf("No permission to access port %s: %s", port_name, strerror(errno));
    return FL_METHOD_RESPONSE(fl_method_error_response_new("PERMISSION_ERROR", error_msg, nullptr));
  }
}
