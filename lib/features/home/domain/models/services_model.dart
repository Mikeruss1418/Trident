import 'package:flutter/cupertino.dart';

class ServiceModel {
  final Widget icon;
  final String title;
  final VoidCallback? onTap;

  ServiceModel({required this.icon, required this.title, this.onTap});
}
