# Çizim Rehberi

Bu dosya, oyuna ekleyeceğin el çizimi PNG'lerin nereye konacağını ve hangi boyutta olması gerektiğini anlatır. Çizim koymadığın her şey için oyun kodla üretilmiş düz renkli yer tutucuyu kullanır; yani hiçbir çizim zorunlu değildir.

## Genel kurallar

- Format: **PNG**, sRGB, 8 bit.
- Dosya adları küçük harf, boşluksuz, İngilizce (`knife.png` gibi).
- Tüm çizimler `art/user/` klasörünün altına konur.
- Çizimlerde gerçek marka, logo ya da başka bir oyuna ait görsel olmamalı.
- Yeni bir PNG ekledikten sonra oyunun onu görmesi için projenin yeniden içe aktarılması gerekir. Bana "çizimi ekledim" demen yeterli.

## Skin desenleri (şu an çalışıyor)

Bir skin = kodla üretilen low-poly model + senin çizdiğin desen. Desen dosyası varsa modelin düz renklerinin yerine geçer.

- Klasör: `art/user/skins/`
- Dosya adı: skin kimliği + `.png`

| Skin | Dosya | Boyut (piksel) | Modelin kapladığı alan |
|---|---|---|---|
| Knife | `knife.png` | 1100 × 300 | 1,10 m × 0,30 m |
| Axe | `axe.png` | 1100 × 440 | 1,10 m × 0,44 m |
| Shuriken | `shuriken.png` | 840 × 840 | 0,84 m × 0,84 m |
| Boomerang | `boomerang.png` | 950 × 900 | 0,95 m × 0,90 m |
| Pistol | `pistol.png` | 700 × 540 | 0,70 m × 0,54 m |

Ölçek 1 metre = 1000 pikseldir. Oran aynı kaldığı sürece daha küçük çizebilirsin (örneğin yarı boyut); 1024 pikselden büyük çizmenin telefonda görünür bir faydası yok.

**Nasıl çizilir**

- Objeyi **yandan** ve **ucu sağa bakacak** şekilde çiz. Tabancada namlu sağa, kanca aşağıya bakar. Baltada sap yatay, keskin ağız sağ altta durur.
- Resim, modelin yandan görünüşünün üstüne tam oturacak şekilde gerilir: resmin sol kenarı modelin en soluna, sağ kenarı ucuna denk gelir.
- Modelin dışında kalan bölgeler görünmez; oraları boş bırakabilir ya da herhangi bir renkle doldurabilirsin. Şeffaflık gerekmez.
- Aynı desen modelin iki yüzünde de görünür.
- Güneş altında okunabilirlik için açık ve doygun renkler kullan; oyunun arka planları koyu tonlardır.
- Uç kısmını (saplanan nokta) gövdeden farklı bir renkle belirtmek oyuncunun kuralı anlamasını kolaylaştırır.

İstersen her skin için modelin silüetini gösteren şablon PNG'ler üretebilirim; üstüne çizersin.

## Henüz bağlanmamış çizimler (sonraki fazlar)

Bunları şimdiden çizebilirsin; sistemleri ilgili fazda kurulacak ve bu tablo o zaman kesinleşecek.

| Çizim | Klasör | Boyut (piksel) | Not | Faz |
|---|---|---|---|---|
| Uygulama ikonu | `art/user/icon/` | 1024 × 1024 | Köşeleri yuvarlama, Android kendi maskesini uygular. Önemli kısım ortadaki 660 × 660 alanda kalsın. | 7 |
| Logo | `art/user/logo/` | 1600 × 800 | Şeffaf arka plan. | 5 |
| Mağaza öne çıkan görseli | `art/user/store/` | 1024 × 500 | Şeffaflık yok. Play Console için. | 8 |
| Arayüz ikonları (coin, elmas, ayarlar vb.) | `art/user/ui/` | 128 × 128 | Şeffaf arka plan, kalın çizgi. | 5 |
| Tema arka plan katmanları | `art/user/backgrounds/<tema>/` | 1080 genişlik, yükseklik serbest (dikeyde tekrar edecek şekilde) | Şeffaf arka planlı katmanlar; alt ve üst kenar birbirine uymalı. | 7 |
