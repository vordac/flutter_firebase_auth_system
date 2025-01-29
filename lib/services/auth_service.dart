import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> register(String email, String password) async {
    try {
      // Проверка существования почты в Firebase Authentication
      List<String> signInMethods =
          // ignore: deprecated_member_use
          await _auth.fetchSignInMethodsForEmail(email);
      if (signInMethods.isNotEmpty) {
        throw 'Email already exists in system';
      }

      // Проверка существования почты в Firestore
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        throw 'Email already exists in system';
      }

      // Регистрация пользователя
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Отправка верификационного письма
      await userCredential.user!.sendEmailVerification();

      // Создание документа в Firestore
      DocumentReference docRef = await _firestore.collection('users').add({
        'id': '', // Будет обновлено позже
        'email': email,
        'isVerified': false,
      });

      // Обновление Document-ID
      await docRef.update({'id': docRef.id});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> checkEmailVerification() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      if (user.emailVerified) {
        // Обновление поля isVerified в Firestore
        QuerySnapshot querySnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: user.email)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          DocumentReference docRef = querySnapshot.docs.first.reference;
          await docRef.update({'isVerified': true});
        }
      }
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        await user.reload();
        if (!user.emailVerified) {
          throw 'Verify your account via email';
        }

        // Сохранение сессии
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userEmail', user.email!);
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('userEmail');
    await _auth.signOut();
  }

  Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userEmail = prefs.getString('userEmail');
    if (userEmail != null) {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        if (user.emailVerified) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}
