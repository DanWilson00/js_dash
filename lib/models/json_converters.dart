import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

/// Converter for Flutter Color objects to/from JSON
class ColorConverter implements JsonConverter<Color, int> {
  const ColorConverter();

  @override
  Color fromJson(int json) => Color(json);

  @override
  int toJson(Color object) => object.value;
}

/// Converter for Duration objects to/from JSON (stores as milliseconds)
class DurationConverter implements JsonConverter<Duration, int> {
  const DurationConverter();

  @override
  Duration fromJson(int json) => Duration(milliseconds: json);

  @override
  int toJson(Duration object) => object.inMilliseconds;
}