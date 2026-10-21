import 'package:bms_core/bms_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

List<int> hex(String s) => [for (final p in s.trim().split(RegExp(r'\s+'))) int.parse(p, radix: 16)];

void main() {
  group('Modbus RTU', () {
    test('request frames match real ones captured from an ECO Battery app', () {
      const m = ModbusRtu();
      expect(m.readHolding(0x04B0, 10), hex('01 03 04 B0 00 0A C5 1A'));
      expect(m.readHolding(0, 0x50), hex('01 03 00 00 00 50 45 F6'));
      expect(m.readHolding(0, 0x62), hex('01 03 00 00 00 62 C4 23'));
      expect(m.readHolding(0, 0x80), hex('01 03 00 00 00 80 44 6A'));
    });

    test('assembler: fragmented read, write echo, exception, garbage', () {
      const m = ModbusRtu();
      final reply = withModbusCrc([1, 3, 4, 0x12, 0x34, 0xAB, 0xCD]);
      final echo = m.writeSingle(0x42, 0x1A0A);
      final err = withModbusCrc([1, 0x83, 2]);
      final a = ModbusAssembler();
      final out = [
        ...a.add([0xFF, 0x00, ...reply.sublist(0, 4)]),
        ...a.add([...reply.sublist(4), ...echo, ...err]),
      ];
      expect(out.map((r) => r.function), [3, 6, 0x83]);
      expect(out[0].registers, [0x1234, 0xABCD]);
      expect(out[1].frame, echo);
      expect(out[2].isException, isTrue);
      expect(out[2].exceptionCode, 2);
    });

    test('128-register reply (byte count wraps to 0)', () {
      final data = List.filled(256, 7);
      final frame = withModbusCrc([1, 3, 0, ...data]);
      final r = ModbusAssembler().add(frame).single;
      expect(r.registers, hasLength(128));
    });
  });

  group('advertisement matching', () {
    BleDevice dev(String name, List<String> services) =>
        BleDevice(deviceId: name, name: name, rssi: -60, services: services);

    final jbd = _Fake('jbd', BleSignature(services: ['ff00']));
    final eco = _Fake('eco', BleSignature(services: ['ff00'], namePattern: RegExp(r'^(W|LZ|EB)')));
    final registry = BatteryRegistry([jbd, eco, PlannedDriver('daly', 'Daly')]);

    test('shared service: name pattern decides', () {
      expect(registry.driverFor(dev('WO231020972022', ['FF00']))?.id, 'eco');
      expect(registry.driverFor(dev('xiaoxiang BMS', ['0000ff00-0000-1000-8000-00805f9b34fb']))?.id, 'jbd');
      expect(registry.driverFor(dev('Tile', ['FEED'])), isNull);
    });

    test('scan filter is the de-duplicated union; planned drivers excluded', () {
      expect(registry.scanServices, ['0000ff00-0000-1000-8000-00805f9b34fb']);
      expect(registry.planned.single.name, 'Daly');
    });
  });
}

class _Fake extends BatteryDriver {
  @override
  final String id;
  @override
  final BleSignature signature;
  _Fake(this.id, this.signature);
  @override
  String get name => id;
  @override
  BatteryCapabilities get capabilities => BatteryCapabilities.full;
  @override
  Battery create(BleDevice device) => throw UnimplementedError();
}
