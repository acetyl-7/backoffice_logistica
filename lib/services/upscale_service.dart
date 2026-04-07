import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single upscaled image with its Firestore metadata
class UpscaledImage {
  final String docId;
  final String imageUrl;
  final String? originalImageUrl;
  final DateTime? timestamp;

  UpscaledImage({
    required this.docId,
    required this.imageUrl,
    this.originalImageUrl,
    this.timestamp,
  });
}

/// Represents a single normal image with its Firestore metadata
class NormalImage {
  final String url;
  final DateTime? timestamp;
  final String source; // 'chat' or 'incident'
  final String docId;  // Firestore Document ID

  NormalImage({
    required this.url,
    this.timestamp,
    required this.source,
    required this.docId,
  });
}

class UpscaleService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upscaled images will be stored here in Storage
  String _getUpscaledImagesPath(String driverId) => 'upscaled_images/$driverId';

  Future<bool> imageExistsInStorage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<NormalImage>> getNormalImages(String driverId) async {
    List<NormalImage> tempImages = [];

    try {
      // 1. Get images from chat messages
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('driverId', isEqualTo: driverId)
          .where('type', isEqualTo: 'image')
          .get();

      for (var doc in messagesSnapshot.docs) {
        final data = doc.data();
        final fileUrl = data['fileUrl'] ?? data['imageUrl'];
        if (fileUrl != null && fileUrl.toString().isNotEmpty) {
          DateTime? ts;
          final rawTs = data['timestamp'];
          if (rawTs is Timestamp) {
            ts = rawTs.toDate();
          }
          tempImages.add(NormalImage(
            url: fileUrl.toString(),
            timestamp: ts,
            source: 'chat',
            docId: doc.id,
          ));
        }
      }

      // 2. Get images from incidents
      final incidentsSnapshot = await FirebaseFirestore.instance
          .collection('incidents')
          .where('driverId', isEqualTo: driverId)
          .get();

      for (var doc in incidentsSnapshot.docs) {
        final data = doc.data();
        final List<dynamic>? imageUrls = data['imageUrls'];
        if (imageUrls != null) {
          DateTime? ts;
          final rawTs = data['incidentDate'] ?? data['timestamp'];
          if (rawTs is Timestamp) {
            ts = rawTs.toDate();
          }
          
          for (var url in imageUrls) {
            tempImages.add(NormalImage(
              url: url.toString(),
              timestamp: ts,
              source: 'incident',
              docId: doc.id,
            ));
          }
        }
      }

      // 3. Get images from refuels
      final refuelsSnapshot = await FirebaseFirestore.instance
          .collection('refuels')
          .where('driverId', isEqualTo: driverId)
          .get();

      for (var doc in refuelsSnapshot.docs) {
        final data = doc.data();
        final receiptUrl = data['receiptUrl'];
        if (receiptUrl != null && receiptUrl.toString().isNotEmpty) {
          DateTime? ts;
          final rawTs = data['timestamp'];
          if (rawTs is Timestamp) {
            ts = rawTs.toDate();
          }
          tempImages.add(NormalImage(
            url: receiptUrl.toString(),
            timestamp: ts,
            source: 'refuel',
            docId: doc.id,
          ));
        }
      }

      // 4. Get images from tasks (operation images & guia images)
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('driverId', isEqualTo: driverId)
          .get();

      for (var doc in tasksSnapshot.docs) {
        final data = doc.data();

        DateTime? ts;
        final rawTs = data['completedAt'] ?? data['timestamp'];
        if (rawTs is Timestamp) {
          ts = rawTs.toDate();
        }

        final operationImageUrl = data['operationImageUrl'];
        if (operationImageUrl != null && operationImageUrl.toString().isNotEmpty) {
          tempImages.add(NormalImage(
            url: operationImageUrl.toString(),
            timestamp: ts,
            source: 'task_operation',
            docId: doc.id,
          ));
        }

        final guiaImageUrl = data['guiaImageUrl'];
        if (guiaImageUrl != null && guiaImageUrl.toString().isNotEmpty) {
          tempImages.add(NormalImage(
            url: guiaImageUrl.toString(),
            timestamp: ts,
            source: 'task_guia',
            docId: doc.id,
          ));
        }
      }

      // Remove duplicates and filter out upscaled paths
      final seenUrls = <String>{};
      final List<NormalImage> uniqueImages = [];
      for (var img in tempImages) {
        if (!seenUrls.contains(img.url) && !img.url.contains('upscaled_images')) {
          seenUrls.add(img.url);
          uniqueImages.add(img);
        }
      }

      // Validate each URL still exists in Storage
      List<NormalImage> validImages = [];
      for (var img in uniqueImages) {
        if (img.url.contains('firebasestorage.googleapis.com')) {
          bool exists = await imageExistsInStorage(img.url);
          if (exists) {
            validImages.add(img);
          } else {
            debugPrint('Image not found in storage (deleted): ${img.url}');
          }
        } else {
          validImages.add(img);
        }
      }

      // Sort by timestamp descending
      validImages.sort((a, b) {
        if (a.timestamp == null && b.timestamp == null) return 0;
        if (a.timestamp == null) return 1;
        if (b.timestamp == null) return -1;
        return b.timestamp!.compareTo(a.timestamp!);
      });

      return validImages;
    } catch (e) {
      debugPrint('Error getting normal images: $e');
      return [];
    }
  }

  Future<List<UpscaledImage>> getUpscaledImages(String driverId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('upscaled_images_db')
          .where('driverId', isEqualTo: driverId)
          .get();

      debugPrint('>>> Firestore returned ${querySnapshot.docs.length} upscaled docs');

      List<UpscaledImage> images = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final String? url = data['imageUrl'] as String?;
        if (url == null || url.isEmpty) continue;

        // Validate the image still exists in Storage
        bool exists = await imageExistsInStorage(url);
        if (!exists) {
          debugPrint('Upscaled image not found in storage, cleaning Firestore record: ${doc.id}');
          // Clean up stale Firestore record
          await FirebaseFirestore.instance.collection('upscaled_images_db').doc(doc.id).delete();
          continue;
        }

        DateTime? ts;
        final rawTs = data['timestamp'];
        if (rawTs is Timestamp) {
          ts = rawTs.toDate();
        }

        images.add(UpscaledImage(
          docId: doc.id,
          imageUrl: url,
          originalImageUrl: data['originalImageUrl'] as String?,
          timestamp: ts,
        ));
      }

      // Sort by timestamp descending
      images.sort((a, b) {
        if (a.timestamp == null && b.timestamp == null) return 0;
        if (a.timestamp == null) return 1;
        if (b.timestamp == null) return -1;
        return b.timestamp!.compareTo(a.timestamp!);
      });

      debugPrint('>>> Total valid upscaled images: ${images.length}');
      return images;
    } catch (e, stack) {
      debugPrint('>>> Error getting upscaled images: $e\n$stack');
      return [];
    }
  }

  Future<void> deleteUpscaledImage(UpscaledImage image) async {
    // Delete from Firebase Storage
    try {
      final ref = _storage.refFromURL(image.imageUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting upscaled image from Storage: $e');
      // Continue even if file is already deleted
    }

    // Delete from Firestore
    await FirebaseFirestore.instance
        .collection('upscaled_images_db')
        .doc(image.docId)
        .delete();
  }

  Future<void> deleteNormalImage(NormalImage image) async {
    // 1. Delete from Firebase Storage (if applicable)
    if (image.url.contains('firebasestorage.googleapis.com')) {
      try {
        final ref = _storage.refFromURL(image.url);
        await ref.delete();
      } catch (e) {
        debugPrint('Error deleting normal image from Storage: $e');
      }
    }

    // 2. Delete reference from Firestore
    if (image.source == 'chat') {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(image.docId)
          .delete();
    } else if (image.source == 'incident') {
      await FirebaseFirestore.instance
          .collection('incidents')
          .doc(image.docId)
          .update({
        'imageUrls': FieldValue.arrayRemove([image.url])
      });
    } else if (image.source == 'refuel') {
      await FirebaseFirestore.instance
          .collection('refuels')
          .doc(image.docId)
          .update({
        'receiptUrl': FieldValue.delete()
      });
    } else if (image.source == 'task_operation') {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(image.docId)
          .update({
        'operationImageUrl': FieldValue.delete()
      });
    } else if (image.source == 'task_guia') {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(image.docId)
          .update({
        'guiaImageUrl': FieldValue.delete()
      });
    }
  }

  Future<bool> processAndSaveUpscale({
    required String driverId,
    required String originalImageUrl,
    required bool deleteOriginal,
  }) async {
    try {
      debugPrint('>>> Start Upscale Process for $driverId');

      // 1. Download original image bytes
      final http.Response originalImageResponse =
          await http.get(Uri.parse(originalImageUrl));
      if (originalImageResponse.statusCode != 200) {
        throw Exception(
            'Failed to download original image (Status ${originalImageResponse.statusCode}).');
      }
      final Uint8List originalBytes = originalImageResponse.bodyBytes;
      debugPrint('>>> Downloaded original image bytes: ${originalBytes.length}');

      // 2. Send to local upscale API
      var request = http.MultipartRequest(
          'POST', Uri.parse('http://192.168.1.77:8000/upscale/'));

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        originalBytes,
        filename: 'image.png',
      ));

      debugPrint('>>> Sending to FastAPI...');
      final http.StreamedResponse response = await request.send();
      debugPrint('>>> FastAPI Response Status: ${response.statusCode}');

      if (response.statusCode != 200) {
        String err = await response.stream.bytesToString();
        debugPrint('>>> API Error Body: $err');
        throw Exception('Upscale API failed with status ${response.statusCode}');
      }

      final Uint8List upscaledBytes = await response.stream.toBytes();
      debugPrint('>>> Received upscale bytes: ${upscaledBytes.length}');

      if (upscaledBytes.isEmpty) {
        throw Exception('Upscale API returned an empty file/bytes');
      }

      // 3. Upload to Firebase Storage
      String fileName = 'upscaled_${DateTime.now().millisecondsSinceEpoch}.png';
      String fullPath = '${_getUpscaledImagesPath(driverId)}/$fileName';
      Reference upscaledRef = _storage.ref().child(fullPath);

      debugPrint('>>> Uploading to Firebase Storage at $fullPath');
      await upscaledRef.putData(
          upscaledBytes, SettableMetadata(contentType: 'image/png'));

      String upscaledDownloadUrl = await upscaledRef.getDownloadURL();
      debugPrint('>>> Upload successful. URL: $upscaledDownloadUrl');

      // 4. Save reference to Firestore
      await FirebaseFirestore.instance.collection('upscaled_images_db').add({
        'driverId': driverId,
        'imageUrl': upscaledDownloadUrl,
        'originalImageUrl': originalImageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('>>> Saved reference to Firestore upscaled_images_db');

      // 5. (Optional) Delete original image
      if (deleteOriginal) {
        debugPrint('>>> Deleting original image...');
        Reference originalRef = _storage.refFromURL(originalImageUrl);
        await originalRef.delete();
      }

      return true;
    } catch (e, stack) {
      debugPrint('Error in upscale process: $e\n$stack');
      throw Exception('Upscale error: $e');
    }
  }
}
