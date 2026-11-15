# Play Console "Data safety" Formu İçin Notlar

Bu notlar, Play Console'daki **Uygulama içeriği → Veri güvenliği** formunu doldururken kullanman içindir. Oyunun kendisi sunucuya veri göndermez; aşağıdaki her şey oyuna eklenen Google SDK'larından (AdMob, UMP, Firebase, Play Billing) kaynaklanır.

Formu göndermeden önce her SDK'nın güncel açıklamasını da kontrol et; Google bu listeleri zaman zaman değiştiriyor:

- AdMob: https://developers.google.com/admob/android/privacy/play-data-disclosure
- Firebase: https://firebase.google.com/docs/android/play-data-disclosure

Önemli: Firebase henüz oyuna bağlı değil. Bağlanmadan yayınlarsan aşağıdaki "Analiz" satırlarını yalnızca AdMob için işaretle.

## Genel sorular

| Soru | Cevap |
|---|---|
| Uygulama, gerekli kullanıcı verisi türlerinden herhangi birini topluyor ya da paylaşıyor mu? | **Evet** |
| Toplanan tüm veriler aktarım sırasında şifreleniyor mu? | **Evet** (SDK'lar HTTPS kullanır) |
| Kullanıcılar verilerinin silinmesini isteyebilir mi? | **Evet**. Gizlilik politikasındaki iletişim adresini göster. Oyun hesabı olmadığı için "hesap silme" bağlantısı gerekmiyor. |

## Veri türleri

| Kategori | Veri türü | Toplanıyor | Paylaşılıyor | İsteğe bağlı mı | Amaç |
|---|---|---|---|---|---|
| Konum | Yaklaşık konum | Evet | Evet | Hayır | Reklamcılık, Analiz |
| Uygulama etkinliği | Uygulama etkileşimleri | Evet | Evet | Hayır | Analiz, Reklamcılık |
| Uygulama bilgisi ve performans | Kilitlenme günlükleri | Evet | Evet | Hayır | Analiz |
| Uygulama bilgisi ve performans | Teşhis verileri | Evet | Evet | Hayır | Analiz |
| Cihaz ya da diğer kimlikler | Cihaz ya da diğer kimlikler (Reklam Kimliği dahil) | Evet | Evet | Hayır | Reklamcılık, Analiz, Sahtekarlığı önleme |
| Finansal bilgiler | Satın alma geçmişi | Evet | Hayır | Hayır | Uygulama işlevselliği |

Notlar:

- **Yaklaşık konum** IP adresinden türetilir; oyun konum izni istemez. Kesin konum toplanmaz.
- **Satın alma geçmişi** yalnızca Play Billing'in "şu ürün alındı" bilgisidir; kart bilgisi oyuna hiç ulaşmaz.
- Verilerin tamamı "geçici olarak işlenmiyor" (yani kalıcı işleniyor) olarak işaretlenmeli.

## Toplanmayanlar

Ad, e-posta adresi, kullanıcı kimliği, adres, telefon numarası, kişiler, fotoğraf ve videolar, ses dosyaları, dosyalar ve belgeler, takvim, mesajlar, sağlık ve fitness verileri, web tarama geçmişi, kesin konum.

## Formla birlikte doldurulacak ilgili bölümler

| Bölüm | Cevap |
|---|---|
| Reklam içeriyor mu? | **Evet** |
| Hedef kitle ve içerik | 13 yaş ve üstü. Uygulama çocuklara yönelik olarak **işaretlenmeyecek**. |
| Reklam Kimliği (AD_ID) kullanımı | **Evet**, amaç: Reklamcılık ve Analiz |
| Gizlilik politikası URL'si | `PRIVACY_POLICY.md` dosyasını yayınladığın sayfanın adresi |
| İçerik derecelendirmesi anketi | Şiddet: yok ya da çok hafif (çizgi film tarzı objeler, kan yok, insan hedef yok). Kumar ve rastgele ödüllü satın alma: **yok**. |

## Gizlilik politikasını yayınlamadan önce

`docs/PRIVACY_POLICY.md` içindeki üç yer tutucuyu doldur: `[DATE]`, `[DEVELOPER NAME]`, `[CONTACT EMAIL]`. Buradaki e-posta herkese açık olacağı için bu iş için ayrı bir adres kullanman iyi olur.
