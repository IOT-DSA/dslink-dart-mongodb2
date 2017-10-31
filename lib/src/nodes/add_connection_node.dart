import 'dart:async';
import 'package:dslink/dslink.dart';
import 'package:dslink/nodes.dart';
import 'package:dslink_dslink_mongodb_management/mongo_dslink.dart';
import 'database_node.dart';

bool isNullOrEmpty(String s) => s == null || s.isEmpty;

class AddConnectionParams {
  static const String name = 'connectionName';
  static const String addr = 'address';
  static const String user = 'username';
  static const String pass = 'password';

  static const String emptyNameErrorMsg =
      'A connection name must be specified.';
  static const String emptyUsernameErrorMsg = 'A username must be specified.';
  static const String emptyPasswordErrorMsg = 'A password must be specified.';
  static const String emptyAddressErrorMsg = 'An address must be specified.';

  static void validateParams(Map<String, String> params) {
    if (isNullOrEmpty(params[AddConnectionParams.name])) {
      throw emptyNameErrorMsg;
    }

    if (isNullOrEmpty(params[AddConnectionParams.user])) {
      throw emptyUsernameErrorMsg;
    }

    if (isNullOrEmpty(params[AddConnectionParams.pass])) {
      throw emptyPasswordErrorMsg;
    }

    if (isNullOrEmpty(params[AddConnectionParams.addr])) {
      throw emptyAddressErrorMsg;
    }

    try {
      Uri.parse(params[AddConnectionParams.addr]);
    } catch (e) {
      throw 'Error parsing Address: $e';
    }
  }
}

class AddConnectionNode extends SimpleNode {
  AddConnectionNode(String path, this._link, this.mongoClientFactory)
      : super(path);

  /// Used for testing only
  AddConnectionNode.withCustomProvider(String path, this._link,
      this.mongoClientFactory, SimpleNodeProvider provider)
      : super(path, provider);

  static const String isType = 'addConnectionAction';
  static const String pathName = 'Add_Connection';

  static Map<String, dynamic> definition() => {
        r'$is': isType,
        r'$name': 'Add Device',
        r'$invokable': 'write',
        r'$params': [
          {
            'name': AddConnectionParams.name,
            'type': 'string',
            'placeholder': 'Database Name'
          },
          {
            'name': AddConnectionParams.addr,
            'type': 'string',
            'placeholder': 'mongodb://<ipaddress>'
          },
          {
            'name': AddConnectionParams.user,
            'type': 'string',
            'placeholder': 'Username'
          },
          {
            'name': AddConnectionParams.pass,
            'type': 'string',
            'editor': 'password'
          },
        ],
      };

  LinkProvider _link;
  final MongoClientFactory mongoClientFactory;

  @override
  Future<Null> onInvoke(Map<String, dynamic> params) async {
    AddConnectionParams.validateParams(params);

    final name = NodeNamer.createName(params[AddConnectionParams.name].trim());

    final nd = provider.getNode('/$name');
    if (nd != null) {
      throw "There's already a connection with that name that exists.";
    }

    final username = params[AddConnectionParams.user];
    final password = params[AddConnectionParams.pass];
    final address = params[AddConnectionParams.addr];
    final parsedAddress = Uri.parse(address);

    final cl = mongoClientFactory.create(parsedAddress, username, password);
    final res = await cl.testConnection();

    switch (res) {
      case AuthResult.ok:
        final dbNode = new DatabaseNode('/$name', cl);
        dbNode.load(DatabaseNode.definition(address, username, password, name));
        provider.setNode('/$name', dbNode);
        _link.save();
        return;
      case AuthResult.notFound:
        throw 'Unable to reach the database';
        break;
      case AuthResult.authError:
        throw 'Unable to authenticate with provided credentials';
        break;
      case AuthResult.other:
      default:
        throw 'Unknown error occured. Check log file for errors';
        break;
    }
  }
}
