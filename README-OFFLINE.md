# 🚀 MoonTun Offline Installation Guide

سیستم کامل آفلاین برای نصب MoonTun در سرورهای ایران بدون نیاز به اینترنت

## 📋 نیازمندی‌ها

- Ubuntu 22.04 یا بالاتر
- دسترسی Root
- حداقل 1GB فضای خالی
- معماری: x86_64, aarch64, یا armv7

## 🛠️ مرحله 1: ایجاد پکیج آفلاین (روی سرور با اینترنت)

### آماده‌سازی سرور خارجی

```bash
# دانلود MoonTun
git clone https://github.com/k4lantar4/moontun.git
cd moontun

# اجرای offline installer
sudo bash offline-installer.sh
```

این اسکریپت تمام موارد زیر را دانلود خواهد کرد:
- پکیج‌های Ubuntu (.deb files)
- باینری‌های EasyTier و Rathole
- Dependencies مورد نیاز
- اسکریپت‌های نصب

### خروجی نهایی
```
moontun-offline-YYYYMMDD-HHMMSS.tar.gz
```

## 📦 مرحله 2: انتقال به سرور ایران

فایل tar.gz ایجاد شده را به سرور ایران منتقل کنید:

```bash
# با SCP
scp moontun-offline-*.tar.gz user@iran-server:/root/

# یا با هر روش دیگر (FTP, USB, etc.)
```

## 🔧 مرحله 3: نصب در سرور ایران

### استخراج پکیج
```bash
cd /root
tar -xzf moontun-offline-*.tar.gz
cd moontun-offline
```

### نصب Dependencies
```bash
cd scripts
sudo ./install-offline.sh
```

### نصب MoonTun
```bash
# کپی اسکریپت اصلی
sudo cp /path/to/moontun.sh /usr/local/bin/moontun
sudo chmod +x /usr/local/bin/moontun

# نصب cores محلی
sudo moontun install-cores-local

# یا استفاده از setup script
cd /root
sudo ./setup-offline.sh
```

## 🚀 مرحله 4: پیکربندی و اجرا

### تنظیم PATH
```bash
export PATH="/usr/local/bin:$PATH"
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
```

### پیکربندی اولیه
```bash
sudo moontun setup
```

### شروع تونل
```bash
# برای سرور ایران
sudo moontun start-iran

# یا حالت عادی
sudo moontun start
```

## 📊 ساختار فایل‌ها

```
moontun-offline/
├── packages/           # پکیج‌های Ubuntu (.deb)
├── bin/               # فایل‌های باینری
│   ├── easytier-core
│   ├── easytier-cli
│   └── rathole
├── scripts/           # اسکریپت‌های نصب
│   └── install-offline.sh
├── cache/             # فایل‌های موقت
├── README.md          # راهنما
└── package-info.txt   # اطلاعات پکیج
```

## 🔍 تست و بررسی

### بررسی نصب
```bash
# بررسی MoonTun
moontun --help

# بررسی cores
ls -la /usr/local/bin/easytier-*
ls -la /usr/local/bin/rathole*

# بررسی وضعیت
sudo moontun status
```

### بررسی شبکه
```bash
# تست ارتباط
ping -c 3 your-foreign-server.com

# مانیتورینگ
sudo moontun monitor
```

## ⚠️ عیب‌یابی

### مشکل نصب پکیج‌ها
```bash
# رفع dependencies شکسته
sudo apt-get install -f

# نصب اجباری
cd moontun-offline/packages
sudo dpkg -i --force-depends *.deb
```

### مشکل مجوز باینری‌ها
```bash
sudo chmod +x /usr/local/bin/easytier-*
sudo chmod +x /usr/local/bin/rathole*
```

### مشکل PATH
```bash
# اضافه کردن دائمی
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### مشکل پیکربندی
```bash
# پاک کردن پیکربندی قبلی
sudo rm -rf /etc/moontun/*

# شروع مجدد
sudo moontun setup
```

## 🎯 پیکربندی‌های خاص ایران

### تنظیمات بهینه برای ایران
```bash
# استفاده از DNS محلی
echo "nameserver 178.22.122.100" > /etc/resolv.conf
echo "nameserver 185.51.200.2" >> /etc/resolv.conf

# بهینه‌سازی TCP
echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
sysctl -p
```

### پورت‌های پیشنهادی
```
443  (HTTPS)
80   (HTTP)
53   (DNS)
8080 (HTTP-Alt)
993  (IMAPS)
995  (POP3S)
```

## 📞 پشتیبانی

### فایل‌های مهم
- **Logs**: `/var/log/moontun/`
- **Config**: `/etc/moontun/`
- **Status**: `/etc/moontun/tunnel_status`

### دستورات مفید
```bash
# مشاهده logs
sudo moontun logs

# مانیتورینگ زنده
sudo moontun monitor

# تشخیص مشکل
sudo moontun diagnose

# بازنشانی کامل
sudo moontun stop
sudo rm -rf /etc/moontun/*
sudo moontun setup
```

## 🔄 بروزرسانی

برای بروزرسانی، مراحل زیر را دنبال کنید:

1. پکیج جدید بسازید
2. Dependencies جدید دانلود کنید
3. انتقال و نصب مجدد

## 💡 نکات مهم

- همیشه backup از پیکربندی بگیرید
- پیش از بروزرسانی، tunnel را متوقف کنید
- از مجوزهای صحیح اطمینان حاصل کنید
- DNS تنظیمات را برای ایران بهینه کنید

---

**ساخته شده برای سرورهای ایران بدون اینترنت** 🇮🇷 