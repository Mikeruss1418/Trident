import 'package:flutter/material.dart';
import 'package:trident/core/constants/app_colors.dart';
import 'package:trident/features/home/domain/models/services_model.dart';

class HomeConstants {
  HomeConstants._();
  static final List<ServiceModel> services = [
    ServiceModel(
      icon: Icon(Icons.upload_rounded, color: AppColors.primary),
      title: "Import",
    ),
    ServiceModel(
      icon: Icon(Icons.folder_open, color: AppColors.primary),
      title: 'Documents',
    ),
  ];
}
