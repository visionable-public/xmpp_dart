import 'dart:convert';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:image/image.dart' as img;
import 'package:xmpp_stone/src/elements/xmpp_attribute.dart';
import 'package:xmpp_stone/src/elements/xmpp_element.dart';

class VCard extends XmppElement {
  dynamic _imageData;

  img.Image? _image;

  VCard(XmppElement? element) {
    if (element != null) {
      for (var child in element.children) {
        addChild(child);
      }
    }
    name = 'vCard';
    addAttribute(XmppAttribute('xmlns', 'vcard-temp'));
    _parseImage();
  }

  String? get fullName => getChild('FN')?.textValue;

  String? get familyName => getChild('N')?.getChild('FAMILY')?.textValue;

  String? get givenName => getChild('N')?.getChild('GIVEN')?.textValue;

  String? get prefixName => getChild('N')?.getChild('PREFIX')?.textValue;

  String? get nickName => getChild('NICKNAME')?.textValue;

  String? get url => getChild('URL')?.textValue;

  String? get bDay => getChild('BDAY')?.textValue;

  String? get organisationName =>
      getChild('ORG')?.getChild('ORGNAME')?.textValue;

  String? get organizationUnit =>
      getChild('ORG')?.getChild('ORGUNIT')?.textValue;

  String? get title => getChild('TITLE')?.textValue;

  String? get role => getChild('ROLE')?.textValue;

  String? get jabberId => getChild('JABBERID')?.textValue;

  String? getItem(String itemName) => getChild(itemName)?.textValue;

  dynamic get imageData => _imageData;

  img.Image? get image => _image;

  String? get imageType => getChild('PHOTO')?.getChild('TYPE')?.textValue;

  List<PhoneItem> get phones {
    var homePhones = <PhoneItem>[];
    children
        .where((element) =>
            (element.name == 'TEL' && element.getChild('HOME') != null))
        .forEach((element) {
      var typeString = element.children.firstWhereOrNull(
          (element) => (element.name != 'HOME' && element.name != 'NUMBER'));
      if (typeString != null) {
        var type = getPhoneTypeFromString(typeString.name);
        var number = element.getChild('NUMBER')?.textValue;
        if (number != null) {
          homePhones.add(PhoneItem(type, number));
        }
      }
    });
    return homePhones;
  }

  String? get emailHome {
    var element = children.firstWhereOrNull(
        (element) =>
            (element.name == 'EMAIL' && element.getChild('HOME') != null));
    return element?.getChild('USERID')?.textValue;
  }

  String? get emailWork {
    var element = children.firstWhereOrNull(
        (element) =>
            (element.name == 'EMAIL' && element.getChild('WORK') != null));
    return element?.getChild('USERID')?.textValue;
  }

  static PhoneType getPhoneTypeFromString(String? phoneTypeString) {
    switch (phoneTypeString) {
      case 'VOICE':
        return PhoneType.voice;
      case 'FAX':
        return PhoneType.fax;
      case 'PAGER':
        return PhoneType.pager;
      case 'MSG':
        return PhoneType.msg;
      case 'CELL':
        return PhoneType.cell;
      case 'VIDEO':
        return PhoneType.video;
      case 'BBS':
        return PhoneType.bbs;
      case 'MODEM':
        return PhoneType.modem;
      case 'ISDN':
        return PhoneType.isdn;
      case 'PCS':
        return PhoneType.pcs;
      case 'PREF':
        return PhoneType.pref;
    }
    return PhoneType.other;
  }

  void _parseImage() {
    var base64Image = getChild('PHOTO')?.getChild('BINVAL')?.textValue;
    if (base64Image != null) {
      _imageData = base64.decode(base64Image);
      _image = img.decodeImage(_imageData);
    }
  }
}

class InvalidVCard extends VCard {
  InvalidVCard(XmppElement? element) : super(element);
}

class PhoneItem {
  PhoneType type;
  String phone;

  PhoneItem(this.type, this.phone);
}

enum PhoneType {
  voice,
  fax,
  pager,
  msg,
  cell,
  video,
  bbs,
  modem,
  isdn,
  pcs,
  pref,
  other
}
