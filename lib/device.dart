class Device {
  final String name;
  final String? description;
  final int baudRate;
  final String port;
  final String? serialNumber;
  final String? manufacturer;
  final String? product;
  final String? protocol;
  final String? protocolVersion;

  const Device({
    required this.name,
    this.description,
    required this.baudRate,
    required this.port,
    this.serialNumber,
    this.manufacturer,
    this.product,
    this.protocol,
    this.protocolVersion,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      name: json['name'],
      description: json['description'],
      baudRate: json['baudRate'],
      port: json['port'],
      serialNumber: json['serialNumber'],
      manufacturer: json['manufacturer'],
      product: json['product'],
      protocol: json['protocol'],
      protocolVersion: json['protocolVersion'],
    );
  }
}
