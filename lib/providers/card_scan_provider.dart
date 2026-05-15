import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../algorithms/card_parser.dart';
import '../models/card_details.dart';

enum CardScanState { idle, scanning, processing, success, error }

class CardScanProvider extends ChangeNotifier {
  CardScanState _state = CardScanState.idle;
  CardDetails? _cardDetails;
  File? _scannedImage;
  String? _errorMessage;
  String? _rawText;

  CardScanState get state => _state;
  CardDetails? get cardDetails => _cardDetails;
  File? get scannedImage => _scannedImage;
  String? get errorMessage => _errorMessage;
  String? get rawText => _rawText;

  bool get isLoading =>
      _state == CardScanState.scanning || _state == CardScanState.processing;

  /// Process an image file: run OCR then parse card details.
  Future<void> processImage(File imageFile) async {
    _state = CardScanState.processing;
    _scannedImage = imageFile;
    _errorMessage = null;
    _rawText = null;
    notifyListeners();

    try {
      // 1. Run ML Kit OCR
      final inputImage = InputImage.fromFile(imageFile);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await recognizer.processImage(inputImage);
      await recognizer.close();

      _rawText = recognizedText.text;

      if (_rawText == null || _rawText!.trim().isEmpty) {
        _state = CardScanState.error;
        _errorMessage =
            'No text detected. Please ensure the card is well-lit and fully visible.';
        notifyListeners();
        return;
      }

      // 2. Parse card details using custom algorithm
      _cardDetails = CardParser.parseCard(_rawText!);

      if (!(_cardDetails?.hasData ?? false)) {
        _state = CardScanState.error;
        _errorMessage =
            'Could not extract card details. Try a clearer image.';
      } else {
        _state = CardScanState.success;
      }
    } catch (e) {
      _state = CardScanState.error;
      _errorMessage = 'An error occurred during scanning: ${e.toString()}';
    }

    notifyListeners();
  }

  void reset() {
    _state = CardScanState.idle;
    _cardDetails = null;
    _scannedImage = null;
    _errorMessage = null;
    _rawText = null;
    notifyListeners();
  }
}
