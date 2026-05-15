import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../algorithms/passbook_parser.dart';
import '../models/bank_details.dart';

enum PassbookScanState { idle, processing, success, error }

class PassbookScanProvider extends ChangeNotifier {
  PassbookScanState _state = PassbookScanState.idle;
  BankDetails? _bankDetails;
  File? _scannedImage;
  String? _errorMessage;
  String? _rawText;

  PassbookScanState get state => _state;
  BankDetails? get bankDetails => _bankDetails;
  File? get scannedImage => _scannedImage;
  String? get errorMessage => _errorMessage;
  String? get rawText => _rawText;

  bool get isLoading => _state == PassbookScanState.processing;

  /// Process an image file: run OCR then parse bank details.
  Future<void> processImage(File imageFile) async {
    _state = PassbookScanState.processing;
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
        _state = PassbookScanState.error;
        _errorMessage =
            'No text detected. Please ensure the document is well-lit and fully visible.';
        notifyListeners();
        return;
      }

      // 2. Parse bank details using custom algorithm
      _bankDetails = PassbookParser.parsePassbook(_rawText!);

      if (!(_bankDetails?.hasData ?? false)) {
        _state = PassbookScanState.error;
        _errorMessage =
            'Could not extract bank details. Try a clearer image or ensure the document contains account information.';
      } else {
        _state = PassbookScanState.success;
      }
    } catch (e) {
      _state = PassbookScanState.error;
      _errorMessage = 'An error occurred during scanning: ${e.toString()}';
    }

    notifyListeners();
  }

  void reset() {
    _state = PassbookScanState.idle;
    _bankDetails = null;
    _scannedImage = null;
    _errorMessage = null;
    _rawText = null;
    notifyListeners();
  }
}
