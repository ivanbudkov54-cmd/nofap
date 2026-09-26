//
//  FirebaseConfig.swift
//  NoFap
//
//  Координаты проекта Firebase. Пока поля пустые, напарник работает на
//  локальной заглушке — приложение не ломается без сервера.
//
//  Ключ не секретный: это публичный идентификатор проекта, он в любом
//  случае лежит внутри приложения. Защищают данные правила Firestore
//  (firestore.rules в корне репозитория), а не скрытность ключа.
//

import Foundation

enum FirebaseConfig {

    /// Firebase Console → Project settings → General → Project ID.
    static let projectID = "nofap-eaec7"

    /// Firebase Console → Project settings → General → Web API Key.
    static let apiKey = "AIzaSyAop6VTBdHzL-q8Ac7TiqVB8Y1aOJawkTE"

    static var isConfigured: Bool { !projectID.isEmpty && !apiKey.isEmpty }
}
