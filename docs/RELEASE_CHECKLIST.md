# Yayın Kontrol Listesi

Upsy Flip'i Google Play'de yayınlamak için baştan sona yapılacaklar. Sırayla ilerle; her bölümün sonundaki kutuları işaretle.

## 0. Şu anki durum

| Konu | Durum |
|---|---|
| Oyun, 5 skin, 2 tema, meta sistemler, 10 dil | Hazır |
| Reklamlar (AdMob) | Eklenti kurulu, Google'ın **test** kimlikleriyle çalışıyor. Gerçek kimlikler takılacak. |
| Satın almalar (Play Billing) | **Bağlı değil.** Yalnızca debug sürümde çalışan sahte mağaza var; yayın sürümünde STORE düğmesi kapalı. |
| Firebase (Analytics, Remote Config) | **Bağlı değil.** Olaylar ve varsayılan değerler hazır, gönderen kısım yok. |
| Release keystore | Senin oluşturman gerekiyor (bölüm 2). |

Billing ve Firebase bağlanmadan da kapalı teste çıkabilirsin; ama v1.0 tanımı ikisini de gerektiriyor. Play Console hesabı ve Firebase projesi açıldığında bunları birlikte bağlarız.

## 1. Hesaplar

- [ ] **Google Play Console** geliştirici hesabı (tek seferlik 25 USD). Kişisel hesapta kimlik doğrulaması birkaç gün sürebilir.
- [ ] **AdMob** hesabı (ücretsiz): https://admob.google.com
- [ ] **Firebase** projesi (ücretsiz): https://console.firebase.google.com
- [ ] Gizlilik politikası için herkese açık bir sayfa (örneğin GitHub Pages ya da Google Sites).
- [ ] Mağazada görünecek bir destek e-posta adresi (kişisel adresinden ayrı olması iyi olur).

## 2. Release keystore (bir kez yapılır)

Keystore, uygulamayı senin imzaladığını kanıtlayan dosyadır.

1. PowerShell'de repo klasöründe çalıştır:
   ```powershell
   .\tools\create_release_keystore.ps1
   ```
2. `keytool` senden iki kez şifre, sonra ad ve kuruluş bilgisi ister. Şifreyi yalnızca sen girersin; hiçbir dosyaya yazılmaz.
3. Dosya şuraya oluşur: `C:\Users\<kullanıcı>\.keystores\upsyflip-upload.jks` (takma ad: `upsyflip-upload`).

**Saklama kuralları**

- Keystore **asla repoya girmez.** `.gitignore` `*.jks` ve `*.keystore` dosyalarını zaten dışlıyor; yine de repo klasörüne kopyalama.
- Dosyayı iki ayrı yere yedekle (örneğin bir USB bellek ve şifreli bir bulut klasörü).
- Şifreyi bir şifre yöneticisine kaydet; dosyayla aynı yerde düz metin olarak tutma.
- Play Console'da uygulamayı oluştururken **Play Uygulama İmzalama**'yı açık bırak (varsayılan). Böylece bu dosya yalnızca "yükleme anahtarı" olur: kaybedersen Google'dan sıfırlama isteyebilirsin. Uygulama imzalama kapalıysa kayıp geri alınamaz.

- [ ] Keystore oluşturuldu
- [ ] İki yere yedeklendi
- [ ] Şifre şifre yöneticisinde

## 3. Gerçek kimliklerin takılacağı yerler

| Ne | Nereye | Not |
|---|---|---|
| AdMob **uygulama kimliği** (`ca-app-pub-…~…`) | Godot editörü: **Proje → Proje Ayarları → AdMob → General → Android → App Id** | Boş kalırsa Google'ın test kimliği kullanılır. |
| AdMob **ödüllü** ve **geçiş** reklam birimi kimlikleri (`ca-app-pub-…/…`) | `data/ads_config.tres` içindeki `rewarded_unit_id` ve `interstitial_unit_id` | AdMob'da iki reklam birimi oluştur: Rewarded ve Interstitial. |
| Uygulama içi ürünler | Play Console → Para kazanma → Ürünler | Kimlikler aşağıdaki tabloyla **birebir** aynı olmalı. Fiyatları orada belirlersin. |
| Firebase | `google-services.json` | Firebase bağlanırken eklenecek. |

**Ürün kimlikleri**

| Kimlik | Tür | İçerik |
|---|---|---|
| `starter_pack` | Tek seferlik | Reklamsız + Gold Knife + 1000 coin |
| `remove_ads` | Tek seferlik | Geçiş reklamlarını kaldırır |
| `coins_small` | Tüketilebilir | 500 coin |
| `coins_medium` | Tüketilebilir | 1500 coin |
| `coins_large` | Tüketilebilir | 5000 coin |
| `gems_small` | Tüketilebilir | 30 gem |
| `gems_medium` | Tüketilebilir | 100 gem |
| `gems_large` | Tüketilebilir | 300 gem |

Uyarı: Gerçek reklam kimliklerini taktıktan sonra **kendi reklamlarına tıklama.** Test ederken AdMob'da telefonunu test cihazı olarak ekle; aksi halde hesabın kapatılabilir.

- [ ] AdMob uygulaması ve iki reklam birimi oluşturuldu
- [ ] Kimlikler projeye girildi
- [ ] Telefon AdMob'da test cihazı olarak eklendi

## 4. Sürüm numaraları

- **Sürüm adı** (`1.0.0`): oyuncunun gördüğü. Büyük değişiklik . yeni içerik . düzeltme.
- **Sürüm kodu** (`1`, `2`, `3`…): Play Console'a yüklenen her dosyada **bir öncekinden büyük** olmalı; aynı sürüm adıyla yeniden yüklesen bile.

Önerilen düzen: kapalı test `1.0.0` (kod 1, 2, 3…), yayın `1.0.0` (o anki en yüksek kod + 1), haftalık meydan okuma güncellemesi `1.1.0`.

## 5. İmzalı AAB üretme

```powershell
.\tools\build_release.ps1 -VersionName 1.0.0 -VersionCode 1
```

Betik sürüm numaralarını yazar, testleri çalıştırır (başarısızsa durur), keystore şifresini gizli olarak sorar ve `build\upsyflip-1.0.0.aab` dosyasını üretir. Şifre yalnızca o işlem süresince bellekte tutulur.

Sonrasında `project.godot` ve `export_presets.cfg` içindeki sürüm değişikliğini commit'le.

- [ ] AAB üretildi
- [ ] Sürüm değişikliği commit'lendi

## 6. Play Console'da uygulamayı hazırlama

1. **Uygulama oluştur:** ad "Upsy Flip: Endless Climb", varsayılan dil İngilizce (ABD), tür Oyun, ücretsiz.
2. **Mağaza girişi:** metinler `docs/STORE_LISTING.md` içinde. İkon 512 × 512, öne çıkan görsel 1024 × 500, en az 2 telefon ekran görüntüsü.
3. **Uygulama içeriği:**
   - Gizlilik politikası URL'si.
   - Reklamlar: **Evet, reklam içeriyor.**
   - Uygulama erişimi: tüm işlevler girişsiz kullanılabiliyor.
   - İçerik derecelendirmesi anketi: şiddet yok ya da çok hafif; kumar yok; rastgele ödüllü satın alma yok.
   - Hedef kitle: **13 yaş ve üstü.** Çocuklara yönelik olarak işaretleme.
   - Veri güvenliği: cevaplar `docs/DATA_SAFETY.md` içinde.
   - Reklam kimliği: Evet (reklamcılık ve analiz).
4. **Ürünler:** bölüm 3'teki sekiz ürünü oluştur ve etkinleştir.

- [ ] Mağaza girişi tamam
- [ ] Uygulama içeriği bölümlerinin hepsi yeşil
- [ ] Ürünler oluşturuldu

## 7. Kapalı test: 12 kullanıcı, 14 gün

Yeni kişisel geliştirici hesaplarında üretime çıkmak için **en az 12 test kullanıcısının kapalı teste katılmış olması ve 14 gün kesintisiz katılımda kalması** gerekiyor.

**Hazırlık**

- [ ] 12'den fazla kişi bul (15–20 kişi güvenli; ayrılanlar olur). Her birinin Android telefonu ve Google hesabı olmalı.
- [ ] Hepsinin Google hesabı e-postalarını topla.
- [ ] Play Console → Test → Kapalı test → yeni kanal oluştur, e-postaları bir listeye ekle.
- [ ] AAB'yi yükle, sürümü incelemeye gönder (ilk inceleme birkaç gün sürebilir).

**Test süresince**

- [ ] İnceleme geçince katılım bağlantısını test kullanıcılarına gönder.
- [ ] Her kullanıcının bağlantıdan **katılıp uygulamayı Play Store'dan yüklediğini** doğrula. Yalnızca listeye eklenmek sayılmaz.
- [ ] 14 günü, 12. kişinin katıldığı günden itibaren say.
- [ ] Bu süre boyunca kimse testten ayrılmasın; sayı 12'nin altına düşerse süre baştan başlayabilir.
- [ ] Kullanıcılardan oyunu ara ara açmalarını iste; Google etkin kullanım da arıyor.
- [ ] Geri bildirimleri topla ve bu sürede en az bir güncelleme yükle (her yüklemede sürüm kodunu artır).

**Sonrasında**

- [ ] Play Console'da "Üretim erişimi için başvur" formunu doldur: testin nasıl yapıldığı, alınan geri bildirim ve yapılan değişiklikler sorulur.
- [ ] Onay gelince üretim sürümünü oluştur ve kademeli yayınla (örneğin %20 ile başla).

## 8. Yayından hemen önce son kontroller

- [ ] `.\tools\build_release.ps1` testleri geçiyor.
- [ ] Gerçek bir telefonda yayın AAB'sinden kurulan sürümde: oyun açılıyor, reklam geliyor, satın alma test kartıyla tamamlanıyor, satın alma uygulama silinip yeniden kurulunca geri geliyor.
- [ ] İzin ekranı (UMP): AdMob → Gizlilik ve mesajlaşma bölümünde GDPR mesajı oluşturuldu ve yayınlandı.
- [ ] Gizlilik politikası sayfası açılıyor, `[DATE]`, `[DEVELOPER NAME]`, `[CONTACT EMAIL]` doldurulmuş.
- [ ] Mağaza ekran görüntüleri güncel sürümden.
- [ ] Repoda keystore, şifre ya da API anahtarı yok: `git status` ve `git log -p` içinde `*.jks`, `*.keystore`, `password` araması temiz.

## 9. Bilinen açık konular

- En düşük Android sürümü 10 (API 29). Daha eskileri desteklemek ayrı bir iş.
- Arayüz ikonları ve nihai uygulama ikonu senin çizimlerini bekliyor (`docs/ART_GUIDE.md`). Çizince `tools/make_icons.gd` ile ikonları yeniden üret.
- Günlük bildirim yok (isteğe bağlıydı).
- Çeviriler ana dili olan kişilerce gözden geçirilmedi.
