# Upsy Flip: Endless Climb — Proje Talimatları

Bu dosya, bu repodaki mobil oyun projesinin ana talimatıdır. Her oturumda önce bu dosyayı oku ve buradaki kurallara uy.

---

## 0. Rolün ve çalışma şeklin

- Sen Godot 4 ile mobil oyun geliştiren kıdemli bir oyun geliştiricisisin. Hedefin, Google Play'de yayınlanacak, global ölçekte başarılı olabilecek, cilalı bir hyper-casual oyun yapmak.
- **Benimle Türkçe konuş.** Kod, değişken adları, yorumlar ve commit mesajları **İngilizce** olsun.
- Oyunu **fazlar halinde** geliştir (bölüm 12). Bir fazı bitirmeden sonrakine geçme. Fazın dışında özellik ekleme.
- Her fazın başında 5-10 maddelik kısa bir plan yaz ve onayımı al. Her fazın sonunda:
  1. Projenin hatasız açıldığını ve çalıştığını doğrula (headless çalıştırma, mümkünse testler).
  2. Anlamlı bir git commit at.
  3. Bana Türkçe kısa bir rapor ver: ne yapıldı, **telefonda neyi nasıl test etmeliyim**, bilinen sorunlar, sonraki faz.
- Bir tasarım kararı bu dokümanda yoksa ve geri dönüşü zorsa **bana sor**. Küçük kararları kendin ver ve rapora yaz.
- Godot editöründe elle yapılması zorunlu bir adım varsa (örneğin bir ayar ekranı), bana tam olarak hangi menüye girip neye tıklayacağımı yaz. Bunun dışında her şeyi kodla ve metin dosyalarıyla yap.

## 1. Teknik ortam (kurulu ve hazır)

- **Motor:** Godot 4.7.2 stable, standart sürüm (GDScript, .NET değil). Konum: `C:\Godot\Godot_v4.7.2-stable_win64.exe` (konsol sürümü de aynı klasörde).
- **Dil:** GDScript, **statik tipli** (`var speed: float = 3.0`, fonksiyonlarda tip ve dönüş tipi).
- **Android:** JDK 17 (Temurin), Android SDK `C:\Android\sdk` (komut satırı araçlarıyla kuruldu, Android Studio yok), export şablonları 4.7.2.stable.
- **İşletim sistemi:** Windows. Terminal PowerShell.
- **Test cihazı:** USB hata ayıklaması açık bir Android telefon.
- İlk iş (Faz 0) olarak bunların hepsinin çalıştığını doğrula. Eksik ya da hatalı bir şey varsa önce onu çöz.

## 2. Oyunun özeti

- **Ad:** Upsy Flip. Mağaza adı: **"Upsy Flip: Endless Climb"** (Google Play'de en fazla 30 karakter).
- **Tür:** Hyper-casual, tek parmakla oynanan, **sonsuz dikey tırmanma** oyunu. İlham kaynağı Flippy Knife (BERESNEV), ama kopyası değil. İsim, görsel ya da metin olarak Flippy Knife'a gönderme yapma.
- **Görünüm:** **3D low-poly** grafikler, **2D oynanış**. Gerçek bir 3D sahne kullan, ama tüm oynanışı X-Y düzlemine kilitle. Kamera yandan baksın, hafif perspektifli olsun ve sadece yukarı doğru takip etsin.
- **Ekran:** Dikey (portrait), tek parmak. Ekranın her yeri dokunma alanıdır.
- **Temel fikir:** Oyuncu bir objeyi (bıçak, tabanca, balta…) dokunarak döndüre döndüre yukarı fırlatır. Obje doğru açıyla bir yüzeye değerse saplanır. Yanlış açıyla değerse seker ve düşer. Amaç olabildiğince yükseğe çıkmak.
- **Hedef his:** Kısa eller (30-90 sn), ölünce 1 saniyede yeniden başlama, "bir el daha" isteği, tatmin edici saplanma anları.

## 3. Çekirdek mekanik (en önemli kısım)

**Fizik motoru kullanma.** RigidBody yerine kendi basit, deterministik hareket sistemini yaz. Bu hem hissi ayarlamayı kolaylaştırır hem de hataları önler.

- **Durumlar:** `STUCK` (bir yüzeye saplı, bekliyor) → `FLYING` (havada dönüyor) → `STUCK` ya da `FALLING` (sekip düşüyor) → `DEAD`.
- **Kontrol:**
  - Ekranın **sol yarısına** dokunmak → obje sola-yukarı fırlar. **Sağ yarısına** dokunmak → sağa-yukarı fırlar.
  - Fırlatma: sabit bir dikey hız, seçilen yöne doğru yatay hız ve sabit bir açısal hız (dönme hızı). Değerler skin'e göre değişir.
  - Havadayken yerçekimi uygulanır. Dönme sürekli devam eder.
- **Saplanma kontrolü:** Objenin **uç noktası** (tip) bir saplanabilir yüzeye değdiğinde objenin açısına bak:
  - Uç yüzeye uygun açı aralığındaysa (örneğin ±35°) → **saplan**.
  - Aralığın daha dar merkezindeyse (örneğin ±10°) → **PERFECT** saplanma.
  - Sap veya gövde önce çarparsa → **sek ve düş** (FALLING). Kural tutarlı ve oyuncuya adil hissettirmeli. "Uç saplandı ama sap çarptı, öldüm" gibi haksız hissettiren durumlar olmamalı. Bu kuralı net ve görsel olarak anlaşılır yap.
- **Ölüm:** Obje kameranın alt sınırının altına düşerse el biter.
- **Skor:** Ulaşılan maksimum yükseklik (metre) + bonuslar. En iyi skor kaydedilir.
- **Tüm his değerleri** (yerçekimi, hızlar, açı aralıkları, kamera takibi, ağır çekim süreleri vb.) tek bir `FeelConfig` Resource dosyasında dursun. Böylece kodu değiştirmeden ayar yapılabilir.
- İsteğe bağlı bir "basılı tutarak güç ayarlama" modunu `FeelConfig` içinde bir ayar olarak hazırla, **varsayılan olarak kapalı** olsun.

## 4. Skinler = farklı mekanikler (oyunun ana farkı)

Skinler sadece görünüş değil, her biri farklı oynanır. Her skin bir `SkinData` Resource'udur: ad, mesh/görsel, fırlatma ve dönme parametreleri, saplanma açısı aralığı, özel yetenek.

| Skin | Mekaniği | Sürüm |
|---|---|---|
| **Knife** (bıçak) | Standart, dengeli. Başlangıç skini. | v1.0 |
| **Pistol** (tabanca) | Saplanmaz ama havadayken **ikinci dokunuşta ateş eder**, geri tepmeyle tekrar yükselir. Sınırlı mermi (örneğin 2), saplanınca dolar. Tutunmak için namlunun altındaki küçük bir kanca yüzeye takılır. | v1.0 |
| **Axe** (balta) | Ağır, yavaş döner, kısa zıplar, ama saplanma açısı geniş. | v1.0 |
| **Shuriken** | Çok hızlı döner, kısa zıplar, **her açıdan** saplanır. | v1.0 |
| **Boomerang** | Iskalarsa düşmeden önce **bir kez** geri döner (ikinci şans). | v1.0 |
| **Katana** | Uzun, havada geçerken kesilebilir objeleri keser. | Sonraki güncelleme |

**Önemli kurallar:**
- Tabanca **jenerik ve çizgi film tarzı** olsun. Glock ya da herhangi bir gerçek silah markasının adı, logosu veya birebir tasarımı kullanılmasın. Gerçekçi değil, oyuncak gibi görünsün.
- Skin sistemi **veri odaklı** olsun: Yeni bir skin eklemek yeni bir `SkinData` dosyası ve asset eklemek demek, kod değiştirmek değil.

## 5. Dünya: sonsuz ve temalı

- Seviye **prosedürel olarak** üretilir: Platformlar (saplanılacak tahtalar/hedefler) yukarı doğru, sol ve sağ arasında değişen konumlarda oluşur. Zorluk yükseklikle yavaş yavaş artar (aralık, hedef boyutu, hareketli platform oranı).
- Üretici **seed alan deterministik bir RNG** kullansın. Aynı seed = aynı harita. Bu, v1.1'deki haftalık meydan okuma için zorunlu.
- **Temalar** veri odaklı bir `ThemeData` Resource'udur: renk paleti, arka plan, platform görünümü, yükseklik aralığı, özel yüzeyler.
- **v1.0 temaları:** 0-100 m **Mutfak**, 100-250 m **Orman**. Sonrasında temalar döngüye girer, zorluk artmaya devam eder. Tema geçişleri yumuşak olsun. Yeni bir temaya ulaşmak oyuncuya bir "an" gibi hissettirsin.
- **İleride eklenecek temalar** (aylık güncellemelerle): Şantiye, Uzay vb. Yeni bir tema eklemek sadece yeni bir `ThemeData` ve asset demek olmalı.
- **Yüzey tipleri:** v1.0'da: normal tahta (saplanılır), hareketli tahta, küçük hedef (bonus puan). Sistem metal (seker), cam (kırılır), buz (kaydırır) gibi yeni yüzeylerin kolayca eklenebileceği şekilde tasarlansın.
- **Bonus objeler:** Karpuz (kesilince coin), balon (patlayınca coin), hedef tahtası (tam ortasına saplanınca ekstra puan).

## 6. Bağımlılık sistemleri

- **Anında yeniden başlama:** Ölüm ekranından tek dokunuşla 1 saniyeden kısa sürede yeni ele geçilir.
- **Perfect → Kombo → Fever:** Her PERFECT saplanma kombo çarpanını artırır. Arka arkaya 5 PERFECT → **Fever modu** (birkaç saniye): ateş izi, parlayan efektler, 2 kat coin, kısa ağır çekim anları.
- **Clutch:** Obje düşerken son anda (alt sınıra yakın) bir yere saplanırsa ağır çekim ve büyük bir "CLUTCH!" yazısı. Ekstra puan.
- **Görünür hedefler:** Duvarda/arka planda oyuncunun **en iyi skoru** bir çizgiyle gösterilir. El bitince "sonraki skin'e %X" şeklinde bir ilerleme çubuğu gösterilir.
- **Günlük giriş serisi:** 7 günlük döngü, her gün artan ödül (coin, 7. gün elmas).
- **Günlük görevler:** Her gün 3 basit görev (örneğin "5 perfect yap", "150 m'ye çık", "Balta ile 3 el oyna"). 5 dakikada bitirilebilir olsunlar.
- **Skin ustalık seviyeleri:** Her skin oynandıkça seviye atlar, küçük kozmetik ödüller (örneğin farklı iz efekti) açar.
- **His (juice):** Saplanmada ekran sarsıntısı, titreşim (haptic), parçacık efekti ve tatmin edici bir "tok" sesi. PERFECT, CLUTCH ve FEVER için belirgin, farklı geri bildirimler.
- **Olmayacaklar:** Ghost (hayalet) sistemi yok. Rastgele ödüllü kasa/sandık sistemi yok.

## 7. Gelir modeli

**İki para birimi:** **Coin** (oynayarak kazanılır) ve **Gem/Elmas** (premium, satın alınır ve nadiren kazanılır). Skinler coin ya da gem ile **doğrudan** satın alınır.

**Uygulama içi satın almalar (IAP):**
- `remove_ads`: Reklamları kaldır (tek seferlik, non-consumable). Ödüllü reklamlar isteğe bağlı olduğu için kalır.
- `starter_pack`: Tek seferlik indirimli paket (reklamsız + özel bir skin + coin).
- `coins_small`, `coins_medium`, `coins_large`: Coin paketleri (consumable).
- `gems_small`, `gems_medium`, `gems_large`: Gem paketleri (consumable).
- **Rastgele içerikli satın alma (loot box) kesinlikle yok.**
- Fiyatlar kodda değil, Play Console'da ayarlanacak. Kod, ürün ID'leri üzerinden çalışsın.

**Reklamlar:**
- **Ödüllü reklam (ana gelir kaynağı):** Ölünce bir kez devam etme hakkı, el sonunda coinleri 2 katına çıkarma, "bu skini bir el dene", günlük ücretsiz coin.
- **Geçiş reklamı (interstitial):** İlk 3 elde hiç gösterilmez. Sonrasında en fazla her 3 elde bir ya da 120 saniyede bir. 15 saniyeden kısa süren bir elin ardından asla gösterilmez. Bu değerler Remote Config ile güncelleme yayınlamadan değiştirilebilir olsun.
- **Banner reklam yok.**

**Teknik:**
- Reklam: **AdMob by Poing Studios** eklentisi (Godot 4.2+, Asset Library'de "AdMob" araması). Test aşamasında mutlaka Google'ın **test reklam birimi ID'lerini** kullan.
- Satın alma: Godot'un resmi **GodotGooglePlayBilling** eklentisi.
  - Tek seferlik ürünleri **3 gün içinde acknowledge et**, aksi halde Google otomatik iade ediyor.
  - Consumable ürünleri `consume_purchase` ile tüket.
  - `PENDING` durumundaki satın almalar için ödül verme, `PURCHASED` olmasını bekle.
  - Uygulama açılışında `query_purchases` ile önceki satın almaları geri yükle.
- **Soyutlama katmanı:** `AdsService` ve `BillingService` arayüzleri olsun, masaüstünde test için **mock (sahte) sürümleri** olsun. Oyun kodu doğrudan eklentiyi çağırmasın.
- **İzin (consent):** AB/İngiltere kullanıcıları için Google UMP izin ekranı. Reklam SDK'sı izin akışından sonra başlatılsın.

## 8. Her yerde oynanabilirlik

Oyun otobüste, sırada beklerken, kısa molalarda oynanacak:
- **Tek elle:** Dikey ekran, tek parmak. Önemli butonlar ekranın alt yarısında, başparmağın ulaştığı yerde.
- **Hızlı açılış:** Uygulama 2-3 saniyede oynanabilir olsun. Açılışta reklam yok. Ana menüden tek dokunuşla oyuna giriş.
- **Otomatik duraklatma:** Uygulama arka plana geçince (telefon çaldı, ekran kapandı) oyun duraklasın. Geri dönünce "3-2-1" sayımıyla devam etsin.
- **Sessiz mod uyumu:** Ses kapalıyken de her önemli an görsel efekt ve titreşimle hissedilsin.
- **Çevrimdışı:** Oyun internetsiz tam oynanabilsin. İlerleme cihazda kaydedilsin. Sadece reklam ve (ileride) liderlik tablosu internet gerektirsin.
- **Performans:** Orta seviye telefonlarda sabit 60 FPS hedefi. Düşük donanımda otomatik kalite düşürme. Ayarlarda kalite seçeneği ve pil tasarrufu modu (menüde FPS düşürme).
- **Boyut:** Hedef uygulama boyutu 100 MB'ın altında.
- **Görsel netlik:** Güneş altında da okunabilsin diye yüksek kontrast. Oynanan obje ve hedefler arka plandan net ayrılsın.
- **Bildirim:** Günde en fazla 1 bildirim (örneğin "Günlük ödülün hazır"). Faz 7'de, isteğe bağlı.

## 9. Global hazırlık

- **Dil:** Ana dil İngilizce. Ayrıca: İspanyolca, Portekizce (Brezilya), Almanca, Fransızca, Rusça, Japonca, Korece, Türkçe, Endonezyaca. Godot'un CSV çeviri sistemini kullan. Oyun içi metni az tut, ikonlarla anlat.
- **Yazı tipi:** Japonca, Korece ve Kiril karakterlerini destekleyen bir font kullan (lisansı ticari kullanıma uygun, örneğin SIL Open Font License).
- **Yaş kitlesi:** Hedef kitle 13 yaş ve üstü. Uygulamayı çocuklara yönelik olarak işaretlemiyoruz.
- **Gizlilik:** Faz 7'de `docs/PRIVACY_POLICY.md` hazırla (İngilizce, AdMob, Firebase ve satın almaları kapsayan). Ben bunu ücretsiz bir web sayfasında yayınlayacağım. Ayrıca Play Console "Data safety" formu için `docs/DATA_SAFETY.md` notları hazırla.
- **Analitik ve Remote Config:** Firebase (Analytics + Remote Config). Temel olaylar: el başlangıcı/bitişi, skor, ölüm nedeni, reklam izlenmesi, satın alma, skin açılması. Faz 6'da entegre et. Masaüstünde mock sürüm çalışsın.

## 10. Assetler (telif kuralları çok önemli)

- **Hiçbir üçüncü taraf asset (model, doku, ses, müzik, font hariç) kullanma.** Her şey bu proje için üretilecek.
- **3D modeller (v1.0):** Low-poly modelleri **Godot içinde kodla** üret (`SurfaceTool` / `ArrayMesh`). Bıçak, tabanca, balta, shuriken, bumerang, tahtalar, platformlar, bonus objeler. Basit ama karakterli, renkli, flat-shaded low-poly stil.
- **İleride:** Daha detaylı modeller için Blender headless (`blender --background --python script.py`) ile `.glb` üretme hattı eklenebilir. Şimdilik gerek yok.
- **Benim çizimlerim:** 2D çizim yapabiliyorum (tablette). Skin desenleri (doku), ikonlar, logo ve arka plan katmanları için PNG çizeceğim. Bunlar için `res://art/user/` klasörünü hazırla ve sistemi şöyle kur: Bir skin = mesh + benim çizdiğim desen dokusu. Ben çizene kadar prosedürel yer tutucular kullan. Her çizim için gereken boyutları ve formatı `docs/ART_GUIDE.md` dosyasına yaz.
- **Sesler:** Ses efektlerini kodla üret (örneğin bir script ile sentezlenmiş WAV dosyaları: saplanma, perfect, fever, clutch, düşme, coin, buton). Müzik v1.0'da zorunlu değil.
- Hiçbir asset'te, metinde ya da kodda gerçek marka, ürün veya başka bir oyunun adı geçmesin.

## 11. Mimari

- **Klasör yapısı (öneri):**
  ```
  res://
    autoload/      # singletons
    core/          # player, flight physics, stick logic, camera
    world/         # level generator, platforms, themes, bonus objects
    skins/         # SkinData resources + skin-specific behaviors
    data/          # FeelConfig, ThemeData, MissionData, ProductCatalog resources
    ui/            # menus, HUD, shop, popups
    services/      # ads, billing, analytics, remote config, save (+ mocks)
    fx/            # particles, shaders, screen shake
    audio/
    art/user/      # user-drawn PNGs
    localization/
    tests/
  docs/
  ```
- **Autoload'lar:** `GameState`, `SaveService`, `Economy`, `AdsService`, `BillingService`, `Analytics`, `RemoteConfig`, `AudioService`, `Haptics`.
- **Veri odaklı:** Skinler, temalar, görevler, ürün kataloğu ve his ayarları `.tres` Resource dosyalarında. Yeni içerik = yeni veri dosyası.
- **Kayıt:** `user://` altında JSON ya da `ConfigFile`. Sürüm numaralı kayıt formatı (ileride göç için). Basit bir bütünlük kontrolü (hile/bozulmaya karşı).
- **Sahneler:** Tüm `.tscn` ve `.tres` dosyaları metin formatında. Sahneleri mümkün olduğunca koddan kur, böylece editöre bağımlılık azalır.
- **İletişim:** Sinyaller. Sistemler birbirine sıkı bağlı olmasın.
- **Test:** Kritik mantık (saplanma açısı kuralı, skor, ekonomi, kayıt, seed'li üretici, reklam sıklığı kuralları) için headless çalışan testler yaz. Her fazın sonunda çalıştır.
- **Güvenlik:** Keystore dosyaları, şifreler ve API anahtarları **asla** repoya girmesin. `.gitignore` zaten bunları dışlıyor, kontrol et.

## 12. Fazlar (yol haritası)

**Faz 0 — Ortam ve iskelet**
Kurulumları doğrula (Godot, JDK 17, Android SDK, export şablonları). Godot projesini oluştur (portrait, mobil renderer ayarları, klasör yapısı, autoload iskeletleri). Basit bir test sahnesini **telefona debug APK olarak yükle** ve çalıştığını doğrula. Android hattının en baştan çalıştığını görmek istiyorum.

**Faz 1 — Çekirdek his prototipi**
Gri kutularla: dokunma, fırlatma, dönme, saplanma/sekme kuralı, ölüm, kamera, yeniden başlama. Sadece Knife. `FeelConfig` ile ayarlanabilir. Telefonda test edilebilir. **Bu fazda his mükemmel olana kadar benimle birlikte ayarla.**

**Faz 2 — Sonsuz seviye**
Seed'li prosedürel üretici, zorluk eğrisi, skor, en iyi skor çizgisi, Mutfak ve Orman temalarının basit hâlleri, tema geçişi, bonus objeler.

**Faz 3 — His (juice) ve özel anlar**
PERFECT, kombo, FEVER, CLUTCH, ekran sarsıntısı, parçacıklar, titreşim, üretilmiş ses efektleri, ağır çekim.

**Faz 4 — Skinler ve görseller**
5 skin ve mekanikleri. Prosedürel low-poly modeller, tema görselleri, benim çizimlerim için doku sistemi, `docs/ART_GUIDE.md`.

**Faz 5 — Meta sistemler**
Coin/gem ekonomisi, mağaza (skin satın alma), günlük giriş serisi, günlük görevler, skin ustalığı, ilerleme çubuğu, kayıt sistemi, ana menü ve ayarlar.

**Faz 6 — Gelir ve servisler**
`AdsService` (AdMob, önce test ID'leri), `BillingService` (Play Billing), UMP izin akışı, Firebase Analytics ve Remote Config. Hepsi mock sürümleriyle masaüstünde de çalışsın.

**Faz 7 — Cila ve global hazırlık**
10 dil, font, otomatik duraklatma, kalite ve pil ayarları, performans optimizasyonu, erişilebilirlik, bildirim, `PRIVACY_POLICY.md`, `DATA_SAFETY.md`, İngilizce mağaza metinleri (kısa ve uzun açıklama, ASO anahtar kelimeleri), uygulama ikonu için öneriler.

**Faz 8 — Yayın hazırlığı**
Release keystore oluşturma (repoya girmeyecek, nerede saklayacağımı söyle), imzalı **AAB** export, sürüm numaralandırma, Play Console kontrol listesi. Not: Yeni kişisel geliştirici hesaplarında üretime çıkmadan önce **en az 12 test kullanıcısıyla 14 gün kesintisiz kapalı test** zorunlu. Bunun için de bir kontrol listesi hazırla.

**v1.0 tamamlanma tanımı:** Telefonda 60 FPS'e yakın akıcı çalışan, 5 skinli, 2 temalı, sonsuz, kayıtlı ilerlemesi olan, reklam ve satın almaları test ortamında çalışan, 10 dilde, imzalı AAB'si hazır bir oyun.

## 13. Sonraki güncellemeler (şimdi yapma, mimariyi buna hazır tut)

- **v1.1 (1. ay): Haftalık meydan okuma.** Her pazartesi herkes aynı seed'le oynar. Her haftanın bir "twist"i var (düşük yerçekimi, sadece balta, buz duvarlar vb.). Seed ve twist Remote Config'ten gelir, güncelleme gerektirmez. Liderlik tablosu (Google Play Games Services ya da Firebase). **Yüzdelik kademeli ödüller:** ilk %1 ve ilk %10 o haftaya özel sezon skini + gem + rozet, ilk %50 coin + gem, katılım küçük coin. Sezon skinleri bir daha asla satılmaz ya da verilmez. Ayrıca yeni tema (Şantiye) + 2-3 skin.
- **v1.2 ve sonrası (aylık):** Her ay 1 yeni tema + 2-3 skin + 1 yeni yüzey ya da engel (metal, cam, buz). Katana skini.

---

**Şimdi Faz 0'dan başla.** Önce kısa planını yaz ve onayımı bekle.
