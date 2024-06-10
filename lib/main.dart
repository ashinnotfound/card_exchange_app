import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '蓝牙名片交换app',
      home: HomePage(),
    );
  }
}

class NameCard {
  final String name;
  final String phone;

  NameCard({required this.name, required this.phone});

  String toJson() {
    return jsonEncode({
      'name': name,
      'phone': phone,
    });
  }

  static NameCard fromJson(String jsonString) {
    final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
    return NameCard(
      name: jsonMap['name'] as String,
      phone: jsonMap['phone'] as String,
    );
  }

  @override
  String toString() {
    return "姓名:$name\n手机号:$phone";
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final List<BluetoothDevice> _discoveredDevices = [];
  final List<BluetoothDevice> _pairedDevices = [];
  NameCard _myNameCard = NameCard(name: '张三', phone: '10086');
  NameCard? _receivedNameCard;
  late IOWebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    _discoverBluetooth();
    _getPairedDevices();
    _connectWebSocket();
  }

  void _connectWebSocket() async {
    var localBluetoothAddress = await FlutterBluetoothSerial.instance.name;
    final url = 'ws://server.ashinnotfound.top:10000/ws/$localBluetoothAddress';
    channel = IOWebSocketChannel.connect(Uri.parse(url));
    channel.stream.listen((message) {
      _showReceivedNameCard(NameCard.fromJson(message));
    }, onError: (error) {}, onDone: () {});
  }

  void _discoverBluetooth() async {
    FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      if (r.device.name != null) {
        setState(() {
          _discoveredDevices.add(r.device);
        });
      }
    });
  }

  void _getPairedDevices() async {
    final pairedDevices =
        await FlutterBluetoothSerial.instance.getBondedDevices();
    setState(() {
      _pairedDevices.addAll(pairedDevices);
    });
  }

  void _sendMyNameCard(BluetoothDevice device) async {
    String content = _myNameCard.toJson();
    try {
      // 通过蓝牙发送名片
      await BluetoothConnection.toAddress(device.address).then((connection) {
        connection.output.add(utf8.encode(content));
        connection.output.allSent.then((_) {
          connection.dispose();
        });
      });
    } catch (e) {
      // 通过WebSocket发送名片
      channel.sink.add('${device.name},$content');
    }
  }

  Future<void> _modifyMyNameCard() async {
    final nameController = TextEditingController(text: _myNameCard.name);
    final phoneController = TextEditingController(text: _myNameCard.phone);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改名片'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名字',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: '手机号',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _myNameCard = NameCard(
                  name: nameController.text,
                  phone: phoneController.text,
                );
              });
              Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showReceivedNameCard(NameCard nameCard) {
    setState(() {
      _receivedNameCard = nameCard;
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('收到名片'),
        content: Text(nameCard.toString()),
      ),
    );
  }

  void _refreshDiscoveredDevices() {
    setState(() {
      _discoveredDevices.clear();
    });
    _discoverBluetooth();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户名片交换'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '我的名片',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text('Name: ${_myNameCard.name}'),
                  const SizedBox(height: 4.0),
                  Text('Phone: ${_myNameCard.phone}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '发现的蓝牙设备',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: _refreshDiscoveredDevices,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = _discoveredDevices[index];
                      return ListTile(
                        title: Text(device.name ?? '未知设备'),
                        subtitle: Text(device.address),
                        onTap: () => _sendMyNameCard(device),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '已配对设备',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _pairedDevices.length,
                    itemBuilder: (context, index) {
                      final device = _pairedDevices[index];
                      return ListTile(
                        title: Text(device.name ?? '未知设备'),
                        subtitle: Text(device.address),
                        onTap: () => _sendMyNameCard(device),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _modifyMyNameCard,
            child: const Text('修改名片'),
          ),
          if (_receivedNameCard != null)
            ElevatedButton(
              onPressed: () => _showReceivedNameCard(_receivedNameCard!),
              child: const Text('查看已接收名片'),
            ),
        ],
      ),
    );
  }
}
