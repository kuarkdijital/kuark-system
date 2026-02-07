# Pencil MCP Skill Module

> .pen dosyalari ile UI/UX tasarimi - Wireframe, mockup, design system, prototyping
> Pencil MCP araclarini kullanarak gorsel tasarim olusturma ve yonetme

## Triggers

- Pencil, .pen, wireframe, mockup
- tasarim, design, ekran tasarimi
- design system, component library
- "wireframe olustur", "ekran tasarla", "design system kur"
- "pen dosyasi ac", "tasarimi guncelle"

---

## Pencil MCP Tool Referansi

### Kesfetme & Baslangic Araclari

| Tool | Ne Yapar | Ne Zaman Kullan |
|------|----------|-----------------|
| `get_editor_state()` | Aktif editor, secim ve .pen dosya bilgisi | Her tasarim oturumunun BASINDA |
| `open_document(path)` | Yeni veya mevcut .pen dosya ac | Tasarim dosyasi olusturma/acma |
| `get_guidelines(topic)` | Tasarim kurallari ve rehber | Tasarim baslamadan once |
| `get_style_guide_tags()` | Mevcut stil etiketleri | Ilham aramadan once |
| `get_style_guide(tags)` | Stil rehberi ve ilham | Tasarim yonu belirlerken |

### Okuma & Arama Araclari

| Tool | Ne Yapar | Ne Zaman Kullan |
|------|----------|-----------------|
| `batch_get(patterns, nodeIds)` | Node'lari ara ve oku | Component kesfetme, yapiyi anlama |
| `snapshot_layout(parentId)` | Layout yapisini kontrol et | Hizalama ve pozisyon dogrulama |
| `get_screenshot(nodeId)` | Node'un gorsel ekran goruntusu | GORSEL DOGRULAMA - her adimda |
| `get_variables()` | Variable ve theme bilgisi | Design system token'larini okuma |
| `find_empty_space_on_canvas()` | Bos alan bul | Yeni ekran yerlestirmeden once |
| `search_all_unique_properties()` | Benzersiz property'leri tara | Tutarlilik kontrolu |

### Yazma & Tasarim Araclari

| Tool | Ne Yapar | Ne Zaman Kullan |
|------|----------|-----------------|
| `batch_design(operations)` | Coklu tasarim operasyonu | TEMEL TASARIM ARACI |
| `set_variables(variables)` | Variable/theme tanimla | Design system kurulumu |
| `replace_all_matching_properties()` | Toplu property degistirme | Global stil guncellemeleri |

---

## Temel Tasarim Workflow'u

### Adim 1: Ortam Hazirla

```
1. get_editor_state(include_schema=true)
   → Aktif dosya var mi? Schema'yi ogren

2. open_document("designs/{proje-adi}.pen")  # Mevcut dosya
   VEYA
   open_document("new")                      # Yeni dosya

3. get_guidelines("design-system")
   → Tasarim kurallari ve component pattern'leri

4. get_style_guide_tags()
   → Hangi stil etiketleri mevcut

5. get_style_guide(tags=["webapp", "dashboard", "modern", "clean", "professional"])
   → Renk paleti, tipografi, spacing ilhami
```

### Adim 2: Design System Kur

```
1. get_variables()
   → Mevcut variable'lari oku

2. set_variables({
     "colors": {
       "primary": { "value": "#3b82f6", "themes": {"dark": "#60a5fa"} },
       "primary-foreground": { "value": "#ffffff", "themes": {"dark": "#1e293b"} },
       "secondary": { "value": "#f1f5f9", "themes": {"dark": "#334155"} },
       "background": { "value": "#ffffff", "themes": {"dark": "#0f172a"} },
       "foreground": { "value": "#0f172a", "themes": {"dark": "#f8fafc"} },
       "muted": { "value": "#f1f5f9", "themes": {"dark": "#1e293b"} },
       "border": { "value": "#e2e8f0", "themes": {"dark": "#334155"} },
       "destructive": { "value": "#ef4444" },
       "warning": { "value": "#f59e0b" },
       "success": { "value": "#22c55e" }
     }
   })
```

### Adim 3: Reusable Component'ler Olustur

```
1. batch_get(patterns=[{reusable: true}])
   → Mevcut reusable component'leri gor

2. batch_design(operations)
   → Ortak component'leri tanimla (Button, Card, Input, Badge vb.)

3. get_screenshot(nodeId)
   → Her component'i gorsel olarak dogrula
```

### Adim 4: Ekran Tasarimi

```
1. find_empty_space_on_canvas(width=1440, height=900, padding=100, direction="right")
   → Yeni ekran icin bos alan bul

2. batch_design(operations)
   → Ekran cercevesi + icerigi olustur (max 25 operation/cagri)

3. get_screenshot(nodeId)
   → MUTLAKA gorsel kontrol yap

4. snapshot_layout(parentId, problemsOnly=true)
   → Hizalama/tasma sorunlarini kontrol et
```

### Adim 5: Dogrulama Dongusu

```
Her ekran icin:
1. get_screenshot() → Gorsel inceleme
2. snapshot_layout(problemsOnly=true) → Teknik kontrol
3. Sorun varsa → batch_design() ile duzelt
4. Tekrar screenshot → Onay
```

---

## batch_design Operation Syntax

### Insert (I) - Yeni Node Ekle
```javascript
// Frame (container) ekleme
container=I("parentId", {type: "frame", layout: "vertical", gap: 16, padding: 24})

// Text ekleme
title=I(container, {type: "text", content: "Dashboard", fontSize: 24, fontWeight: "bold"})

// Rectangle ekleme
bg=I("parentId", {type: "rectangle", width: 200, height: 100, fill: "#3b82f6", cornerRadius: [8,8,8,8]})
```

### Copy (C) - Node Kopyala
```javascript
// Bir node'u kopyalayip property override et
card2=C("card1Id", "parentId", {name: "Card 2"})

// Component instance kopyala ve descendants override et
card2=C("cardCompId", container, {descendants: {"titleText": {content: "Yeni Baslik"}}})
```

### Update (U) - Property Guncelle
```javascript
// Dogrudan property guncelle
U("nodeId", {fill: "#f59e0b", width: 300})

// Component instance icindeki child'i guncelle
U("instanceId/childId", {content: "Guncellenmis metin"})
```

### Replace (R) - Node Degistir
```javascript
// Bir node'u tamamen degistir
newNode=R("eskiNodeId", {type: "text", content: "Yeni icerik"})

// Component instance icindeki slot'u degistir
newSlot=R("instanceId/slotId", {type: "frame", layout: "horizontal"})
```

### Delete (D) - Node Sil
```javascript
D("silinecekNodeId")
```

### Move (M) - Node Tasi
```javascript
// Baska parent'a tasi
M("nodeId", "yeniParentId")

// Belirli index'e tasi
M("nodeId", "parentId", 0)  // Basa tasi
```

### Generate Image (G) - Gorsel Olustur
```javascript
// Once frame olustur, sonra gorsel ekle
heroImg=I("parentId", {type: "frame", width: 400, height: 300})
G(heroImg, "stock", "modern office workspace")

// AI ile gorsel olustur
G(heroImg, "ai", "minimalist dashboard illustration, flat design, blue tones")
```

---

## SaaS Ekran Sablonlari

### Dashboard Ekrani

```javascript
// Ana ekran cercevesi
screen=I(document, {type: "frame", name: "Dashboard", width: 1440, height: 900, fill: "#f8fafc", layout: "horizontal"})

// Sidebar (240px)
sidebar=I(screen, {type: "frame", name: "Sidebar", width: 240, height: "fill_container", fill: "#1e293b", layout: "vertical", padding: 16, gap: 8})
logo=I(sidebar, {type: "text", content: "AppName", fontSize: 20, fontWeight: "bold", textColor: "#ffffff"})
sep=I(sidebar, {type: "rectangle", width: "fill_container", height: 1, fill: "#334155"})
nav1=I(sidebar, {type: "text", content: "Dashboard", fontSize: 14, textColor: "#94a3b8"})
nav2=I(sidebar, {type: "text", content: "Features", fontSize: 14, textColor: "#64748b"})
nav3=I(sidebar, {type: "text", content: "Settings", fontSize: 14, textColor: "#64748b"})

// Main content area
main=I(screen, {type: "frame", name: "MainContent", width: "fill_container", height: "fill_container", layout: "vertical", padding: 32, gap: 24})

// Header
header=I(main, {type: "frame", layout: "horizontal", width: "fill_container", gap: 16})
pageTitle=I(header, {type: "text", content: "Dashboard", fontSize: 24, fontWeight: "bold"})

// KPI Cards row
kpiRow=I(main, {type: "frame", layout: "horizontal", width: "fill_container", gap: 16})
```

```javascript
// KPI Card 1
kpi1=I(kpiRow, {type: "frame", width: "fill_container", height: 120, fill: "#ffffff", cornerRadius: [8,8,8,8], padding: 20, layout: "vertical", gap: 8, stroke: "#e2e8f0", strokeThickness: 1})
kpi1Label=I(kpi1, {type: "text", content: "Total Users", fontSize: 14, textColor: "#64748b"})
kpi1Value=I(kpi1, {type: "text", content: "2,847", fontSize: 28, fontWeight: "bold", textColor: "#0f172a"})
kpi1Change=I(kpi1, {type: "text", content: "+12.5%", fontSize: 12, textColor: "#22c55e"})

// KPI Card 2
kpi2=I(kpiRow, {type: "frame", width: "fill_container", height: 120, fill: "#ffffff", cornerRadius: [8,8,8,8], padding: 20, layout: "vertical", gap: 8, stroke: "#e2e8f0", strokeThickness: 1})
kpi2Label=I(kpi2, {type: "text", content: "Revenue", fontSize: 14, textColor: "#64748b"})
kpi2Value=I(kpi2, {type: "text", content: "$45,290", fontSize: 28, fontWeight: "bold", textColor: "#0f172a"})
kpi2Change=I(kpi2, {type: "text", content: "+8.2%", fontSize: 12, textColor: "#22c55e"})

// KPI Card 3
kpi3=I(kpiRow, {type: "frame", width: "fill_container", height: 120, fill: "#ffffff", cornerRadius: [8,8,8,8], padding: 20, layout: "vertical", gap: 8, stroke: "#e2e8f0", strokeThickness: 1})
kpi3Label=I(kpi3, {type: "text", content: "Active Projects", fontSize: 14, textColor: "#64748b"})
kpi3Value=I(kpi3, {type: "text", content: "156", fontSize: 28, fontWeight: "bold", textColor: "#0f172a"})
kpi3Change=I(kpi3, {type: "text", content: "-2.1%", fontSize: 12, textColor: "#ef4444"})

// Data Table area
tableCard=I(main, {type: "frame", width: "fill_container", height: "fill_container", fill: "#ffffff", cornerRadius: [8,8,8,8], padding: 24, layout: "vertical", gap: 16, stroke: "#e2e8f0", strokeThickness: 1})
tableTitle=I(tableCard, {type: "text", content: "Recent Activity", fontSize: 16, fontWeight: "600"})
```

### List/CRUD Ekrani

```javascript
// List ekran cercevesi
screen=I(document, {type: "frame", name: "Feature List", width: 1440, height: 900, fill: "#f8fafc", layout: "horizontal"})

// Sidebar (reusable component kullan veya kopyala)
// sidebar=C("sidebarCompId", screen, {...})

// Main content
main=I(screen, {type: "frame", width: "fill_container", height: "fill_container", layout: "vertical", padding: 32, gap: 24})

// Toolbar
toolbar=I(main, {type: "frame", layout: "horizontal", width: "fill_container", gap: 12})
pageTitle=I(toolbar, {type: "text", content: "Features", fontSize: 24, fontWeight: "bold", width: "fill_container"})
searchBox=I(toolbar, {type: "frame", width: 240, height: 40, fill: "#ffffff", cornerRadius: [6,6,6,6], padding: 8, stroke: "#e2e8f0", strokeThickness: 1})
searchText=I(searchBox, {type: "text", content: "Search...", fontSize: 14, textColor: "#94a3b8"})
addBtn=I(toolbar, {type: "frame", width: 120, height: 40, fill: "#3b82f6", cornerRadius: [6,6,6,6], layout: "horizontal", gap: 8, padding: 8})
addBtnText=I(addBtn, {type: "text", content: "+ Add New", fontSize: 14, textColor: "#ffffff", fontWeight: "500"})

// Table
table=I(main, {type: "frame", width: "fill_container", fill: "#ffffff", cornerRadius: [8,8,8,8], layout: "vertical", stroke: "#e2e8f0", strokeThickness: 1})

// Table header
thead=I(table, {type: "frame", layout: "horizontal", width: "fill_container", padding: 16, fill: "#f8fafc", gap: 16})
thName=I(thead, {type: "text", content: "Name", fontSize: 12, fontWeight: "600", textColor: "#64748b", width: "fill_container"})
thStatus=I(thead, {type: "text", content: "Status", fontSize: 12, fontWeight: "600", textColor: "#64748b", width: 100})
thDate=I(thead, {type: "text", content: "Created", fontSize: 12, fontWeight: "600", textColor: "#64748b", width: 120})
thActions=I(thead, {type: "text", content: "Actions", fontSize: 12, fontWeight: "600", textColor: "#64748b", width: 80})
```

```javascript
// Table rows
row1=I(table, {type: "frame", layout: "horizontal", width: "fill_container", padding: 16, gap: 16, stroke: "#f1f5f9", strokeThickness: 1})
r1Name=I(row1, {type: "text", content: "User Authentication", fontSize: 14, width: "fill_container"})
r1Badge=I(row1, {type: "frame", width: 100, height: 24, fill: "#dcfce7", cornerRadius: [12,12,12,12], padding: 4})
r1BadgeText=I(r1Badge, {type: "text", content: "Active", fontSize: 12, textColor: "#166534"})
r1Date=I(row1, {type: "text", content: "Jan 15, 2025", fontSize: 14, textColor: "#64748b", width: 120})
r1Actions=I(row1, {type: "text", content: "...", fontSize: 14, textColor: "#94a3b8", width: 80})

row2=I(table, {type: "frame", layout: "horizontal", width: "fill_container", padding: 16, gap: 16, stroke: "#f1f5f9", strokeThickness: 1})
r2Name=I(row2, {type: "text", content: "Payment Integration", fontSize: 14, width: "fill_container"})
r2Badge=I(row2, {type: "frame", width: 100, height: 24, fill: "#fef3c7", cornerRadius: [12,12,12,12], padding: 4})
r2BadgeText=I(r2Badge, {type: "text", content: "Draft", fontSize: 12, textColor: "#92400e"})
r2Date=I(row2, {type: "text", content: "Jan 20, 2025", fontSize: 14, textColor: "#64748b", width: 120})
r2Actions=I(row2, {type: "text", content: "...", fontSize: 14, textColor: "#94a3b8", width: 80})
```

### Form Ekrani

```javascript
// Form ekrani
screen=I(document, {type: "frame", name: "Create Feature", width: 1440, height: 900, fill: "#f8fafc", layout: "horizontal"})

// Main content (sidebar haric)
main=I(screen, {type: "frame", width: "fill_container", height: "fill_container", layout: "vertical", padding: 32, gap: 24})

// Breadcrumb + Back
breadcrumb=I(main, {type: "frame", layout: "horizontal", gap: 8})
backText=I(breadcrumb, {type: "text", content: "< Features", fontSize: 14, textColor: "#3b82f6"})
bcSep=I(breadcrumb, {type: "text", content: "/", fontSize: 14, textColor: "#94a3b8"})
bcCurrent=I(breadcrumb, {type: "text", content: "Create New", fontSize: 14, textColor: "#64748b"})

// Page title
title=I(main, {type: "text", content: "Create Feature", fontSize: 24, fontWeight: "bold"})

// Form card
card=I(main, {type: "frame", width: 720, fill: "#ffffff", cornerRadius: [8,8,8,8], padding: 32, layout: "vertical", gap: 24, stroke: "#e2e8f0", strokeThickness: 1})

// Section 1: General Info
sec1Title=I(card, {type: "text", content: "General Information", fontSize: 16, fontWeight: "600"})

// Name field
nameGroup=I(card, {type: "frame", layout: "vertical", gap: 6, width: "fill_container"})
nameLabel=I(nameGroup, {type: "text", content: "Feature Name *", fontSize: 14, fontWeight: "500"})
nameInput=I(nameGroup, {type: "frame", width: "fill_container", height: 40, fill: "#ffffff", cornerRadius: [6,6,6,6], padding: 8, stroke: "#e2e8f0", strokeThickness: 1})
namePlaceholder=I(nameInput, {type: "text", content: "Enter feature name...", fontSize: 14, textColor: "#94a3b8"})

// Description field
descGroup=I(card, {type: "frame", layout: "vertical", gap: 6, width: "fill_container"})
descLabel=I(descGroup, {type: "text", content: "Description", fontSize: 14, fontWeight: "500"})
descInput=I(descGroup, {type: "frame", width: "fill_container", height: 100, fill: "#ffffff", cornerRadius: [6,6,6,6], padding: 8, stroke: "#e2e8f0", strokeThickness: 1})
descPlaceholder=I(descInput, {type: "text", content: "Describe the feature...", fontSize: 14, textColor: "#94a3b8"})
```

```javascript
// Status select
statusGroup=I(card, {type: "frame", layout: "vertical", gap: 6, width: "fill_container"})
statusLabel=I(statusGroup, {type: "text", content: "Status", fontSize: 14, fontWeight: "500"})
statusSelect=I(statusGroup, {type: "frame", width: 240, height: 40, fill: "#ffffff", cornerRadius: [6,6,6,6], padding: 8, layout: "horizontal", stroke: "#e2e8f0", strokeThickness: 1})
statusValue=I(statusSelect, {type: "text", content: "Draft", fontSize: 14, width: "fill_container"})
statusArrow=I(statusSelect, {type: "text", content: "v", fontSize: 14, textColor: "#94a3b8"})

// Separator
separator=I(card, {type: "rectangle", width: "fill_container", height: 1, fill: "#e2e8f0"})

// Action buttons
actions=I(card, {type: "frame", layout: "horizontal", gap: 12, width: "fill_container"})
spacer=I(actions, {type: "frame", width: "fill_container"})
cancelBtn=I(actions, {type: "frame", width: 100, height: 40, fill: "#ffffff", cornerRadius: [6,6,6,6], padding: 8, stroke: "#e2e8f0", strokeThickness: 1})
cancelText=I(cancelBtn, {type: "text", content: "Cancel", fontSize: 14, textColor: "#64748b"})
saveBtn=I(actions, {type: "frame", width: 120, height: 40, fill: "#3b82f6", cornerRadius: [6,6,6,6], padding: 8})
saveText=I(saveBtn, {type: "text", content: "Save Feature", fontSize: 14, textColor: "#ffffff", fontWeight: "500"})
```

### Login Ekrani

```javascript
// Login ekrani
screen=I(document, {type: "frame", name: "Login", width: 1440, height: 900, fill: "#f8fafc", layout: "horizontal"})

// Sol panel - branding
leftPanel=I(screen, {type: "frame", width: "fill_container", height: "fill_container", fill: "#1e293b", layout: "vertical", padding: 64, gap: 24})
brandLogo=I(leftPanel, {type: "text", content: "AppName", fontSize: 32, fontWeight: "bold", textColor: "#ffffff"})
brandTagline=I(leftPanel, {type: "text", content: "Your workspace, simplified.", fontSize: 18, textColor: "#94a3b8"})

// Sag panel - form
rightPanel=I(screen, {type: "frame", width: "fill_container", height: "fill_container", fill: "#ffffff", layout: "vertical", padding: 64, gap: 32})
spacerTop=I(rightPanel, {type: "frame", height: "fill_container"})
loginTitle=I(rightPanel, {type: "text", content: "Welcome back", fontSize: 24, fontWeight: "bold"})
loginSubtitle=I(rightPanel, {type: "text", content: "Sign in to your account", fontSize: 14, textColor: "#64748b"})

// Email
emailGroup=I(rightPanel, {type: "frame", layout: "vertical", gap: 6, width: 360})
emailLabel=I(emailGroup, {type: "text", content: "Email", fontSize: 14, fontWeight: "500"})
emailInput=I(emailGroup, {type: "frame", width: "fill_container", height: 44, cornerRadius: [8,8,8,8], padding: 12, stroke: "#e2e8f0", strokeThickness: 1})
emailPlaceholder=I(emailInput, {type: "text", content: "name@company.com", fontSize: 14, textColor: "#94a3b8"})

// Password
passGroup=I(rightPanel, {type: "frame", layout: "vertical", gap: 6, width: 360})
passLabel=I(rightPanel, {type: "text", content: "Password", fontSize: 14, fontWeight: "500"})
passInput=I(passGroup, {type: "frame", width: "fill_container", height: 44, cornerRadius: [8,8,8,8], padding: 12, stroke: "#e2e8f0", strokeThickness: 1})
passPlaceholder=I(passInput, {type: "text", content: "Enter your password", fontSize: 14, textColor: "#94a3b8"})

// Sign in button
signInBtn=I(rightPanel, {type: "frame", width: 360, height: 44, fill: "#3b82f6", cornerRadius: [8,8,8,8], padding: 12})
signInText=I(signInBtn, {type: "text", content: "Sign in", fontSize: 14, fontWeight: "600", textColor: "#ffffff"})

spacerBot=I(rightPanel, {type: "frame", height: "fill_container"})
```

---

## State Tasarimlari

Her ekranin 4 state'i tasarlanmali. Her state ayri bir frame olarak olusturulur.

### Loading State Pattern
```javascript
// Loading skeleton
loadingScreen=I(document, {type: "frame", name: "Dashboard - Loading", width: 1440, height: 900, fill: "#f8fafc", layout: "horizontal"})
// ... sidebar ayni ...
loadMain=I(loadingScreen, {type: "frame", width: "fill_container", layout: "vertical", padding: 32, gap: 24})

// Skeleton KPI cards
skRow=I(loadMain, {type: "frame", layout: "horizontal", gap: 16, width: "fill_container"})
sk1=I(skRow, {type: "frame", width: "fill_container", height: 120, fill: "#e2e8f0", cornerRadius: [8,8,8,8]})
sk2=I(skRow, {type: "frame", width: "fill_container", height: 120, fill: "#e2e8f0", cornerRadius: [8,8,8,8]})
sk3=I(skRow, {type: "frame", width: "fill_container", height: 120, fill: "#e2e8f0", cornerRadius: [8,8,8,8]})

// Skeleton table
skTable=I(loadMain, {type: "frame", width: "fill_container", height: 300, fill: "#e2e8f0", cornerRadius: [8,8,8,8]})
```

### Error State Pattern
```javascript
// Error state
errorScreen=I(document, {type: "frame", name: "Dashboard - Error", width: 1440, height: 900, fill: "#f8fafc", layout: "horizontal"})
// ... sidebar ayni ...
errMain=I(errorScreen, {type: "frame", width: "fill_container", layout: "vertical", padding: 32, gap: 24})
errCard=I(errMain, {type: "frame", width: "fill_container", fill: "#fef2f2", cornerRadius: [8,8,8,8], padding: 24, layout: "vertical", gap: 12, stroke: "#fca5a5", strokeThickness: 1})
errTitle=I(errCard, {type: "text", content: "Something went wrong", fontSize: 16, fontWeight: "600", textColor: "#dc2626"})
errMsg=I(errCard, {type: "text", content: "Failed to load dashboard data. Please try again.", fontSize: 14, textColor: "#7f1d1d"})
retryBtn=I(errCard, {type: "frame", width: 120, height: 36, fill: "#ffffff", cornerRadius: [6,6,6,6], padding: 8, stroke: "#fca5a5", strokeThickness: 1})
retryText=I(retryBtn, {type: "text", content: "Try Again", fontSize: 14, textColor: "#dc2626"})
```

### Empty State Pattern
```javascript
// Empty state
emptyScreen=I(document, {type: "frame", name: "Features - Empty", width: 1440, height: 900, fill: "#f8fafc", layout: "horizontal"})
// ... sidebar + toolbar ayni ...
emptyMain=I(emptyScreen, {type: "frame", width: "fill_container", layout: "vertical", padding: 64, gap: 16})
emptyIcon=I(emptyMain, {type: "frame", width: 80, height: 80, fill: "#f1f5f9", cornerRadius: [40,40,40,40]})
emptyTitle=I(emptyMain, {type: "text", content: "No features yet", fontSize: 18, fontWeight: "600", textColor: "#334155"})
emptyDesc=I(emptyMain, {type: "text", content: "Get started by creating your first feature", fontSize: 14, textColor: "#64748b"})
emptyBtn=I(emptyMain, {type: "frame", width: 160, height: 40, fill: "#3b82f6", cornerRadius: [6,6,6,6], padding: 8})
emptyBtnText=I(emptyBtn, {type: "text", content: "+ Create Feature", fontSize: 14, textColor: "#ffffff", fontWeight: "500"})
```

---

## Reusable Component Tanimlama

Tekrar kullanilacak component'leri `reusable: true` ile tanimla:

```javascript
// Button component (reusable)
btn=I(document, {type: "frame", name: "Button", reusable: true, width: 120, height: 40, fill: "#3b82f6", cornerRadius: [6,6,6,6], padding: 8, layout: "horizontal", gap: 8})
btnText=I(btn, {type: "text", name: "label", content: "Button", fontSize: 14, fontWeight: "500", textColor: "#ffffff"})

// Kullanim: ref olarak ekle
myBtn=I("parentId", {type: "ref", ref: btn, width: 140})
U(myBtn+"/label", {content: "Save Changes"})
```

```javascript
// Input component (reusable)
input=I(document, {type: "frame", name: "Input", reusable: true, width: 320, height: 40, fill: "#ffffff", cornerRadius: [6,6,6,6], padding: 8, stroke: "#e2e8f0", strokeThickness: 1})
inputText=I(input, {type: "text", name: "placeholder", content: "Enter value...", fontSize: 14, textColor: "#94a3b8"})

// Badge component (reusable)
badge=I(document, {type: "frame", name: "Badge", reusable: true, height: 24, fill: "#dcfce7", cornerRadius: [12,12,12,12], padding: 6, paddingLeft: 10, paddingRight: 10})
badgeText=I(badge, {type: "text", name: "label", content: "Active", fontSize: 12, fontWeight: "500", textColor: "#166534"})

// Card component (reusable)
card=I(document, {type: "frame", name: "Card", reusable: true, width: 360, fill: "#ffffff", cornerRadius: [8,8,8,8], padding: 24, layout: "vertical", gap: 16, stroke: "#e2e8f0", strokeThickness: 1})
cardTitle=I(card, {type: "text", name: "title", content: "Card Title", fontSize: 16, fontWeight: "600"})
cardDesc=I(card, {type: "text", name: "description", content: "Card description text goes here", fontSize: 14, textColor: "#64748b"})
```

---

## Design Sytem Renk Token'lari

### shadcn/ui Uyumlu Renk Sistemi

```
set_variables({
  "background": { "value": "#ffffff", "themes": {"dark": "#020817"} },
  "foreground": { "value": "#020817", "themes": {"dark": "#f8fafc"} },
  "card": { "value": "#ffffff", "themes": {"dark": "#020817"} },
  "card-foreground": { "value": "#020817", "themes": {"dark": "#f8fafc"} },
  "primary": { "value": "#0f172a", "themes": {"dark": "#f8fafc"} },
  "primary-foreground": { "value": "#f8fafc", "themes": {"dark": "#0f172a"} },
  "secondary": { "value": "#f1f5f9", "themes": {"dark": "#1e293b"} },
  "secondary-foreground": { "value": "#0f172a", "themes": {"dark": "#f8fafc"} },
  "muted": { "value": "#f1f5f9", "themes": {"dark": "#1e293b"} },
  "muted-foreground": { "value": "#64748b", "themes": {"dark": "#94a3b8"} },
  "accent": { "value": "#f1f5f9", "themes": {"dark": "#1e293b"} },
  "destructive": { "value": "#ef4444", "themes": {"dark": "#7f1d1d"} },
  "border": { "value": "#e2e8f0", "themes": {"dark": "#1e293b"} },
  "input": { "value": "#e2e8f0", "themes": {"dark": "#1e293b"} },
  "ring": { "value": "#3b82f6" }
})
```

---

## Landing Page Tasarimi

Landing page icin farkli guideline kullan:

```
1. get_guidelines("landing-page")
   → Landing page ozel kurallari

2. get_style_guide_tags()
3. get_style_guide(tags=["website", "landing", "modern", "hero", "saas"])
   → Web sitesi ilhami
```

### Landing Page Bolumleri
1. **Hero** - Baslik, alt baslik, CTA, gorsel
2. **Features** - 3-4 sutun feature grid
3. **Social Proof** - Logolar, testimonials
4. **Pricing** - Plan kartlari
5. **CTA** - Son cagri
6. **Footer** - Linkler, copyright

---

## Gorsel Dogrulama Protokolu

Her tasarim adiminda su kontrolleri yap:

### 1. Screenshot Kontrolu
```
get_screenshot(nodeId="ekranId")
→ Gorsel olarak kontrol et:
  - Layout dogru mu?
  - Metin okunabiliyor mu?
  - Renk kontrastlari yeterli mi?
  - Spacing tutarli mi?
  - Elemanlar tasmiyor mu?
```

### 2. Layout Kontrolu
```
snapshot_layout(parentId="ekranId", problemsOnly=true)
→ Teknik kontrol:
  - Clipped (tasmis) elemanlar var mi?
  - Overlapping (ust uste binen) elemanlar var mi?
  - Beklenmedik bosluklar var mi?
```

### 3. Tutarlilik Kontrolu
```
search_all_unique_properties(parents=["ekranId"], properties=["fontSize", "fillColor", "textColor"])
→ Tutarlilik kontrol:
  - Kac farkli font boyutu var? (Tipografi hiyerarsisi)
  - Kac farkli renk var? (Renk paleti)
  - Beklenmedik degerler var mi?
```

---

## Code Generation (Developer Handoff)

Tasarim tamamlandiginda, kod uretim icin:

```
1. get_guidelines("code")
   → Kod uretim kurallari

2. get_guidelines("tailwind")
   → Tailwind CSS ozel kurallar

3. get_variables()
   → CSS degiskenleri icin theme token'lari
```

Bu bilgileri NextJS Developer'a handoff dosyasinda teslim et.

---

## Validation Checklist

- [ ] `get_editor_state()` ile baslandi
- [ ] `get_guidelines()` ile kurallar okundu
- [ ] `get_style_guide()` ile stil yonu belirlendi
- [ ] Design system variable'lari `set_variables()` ile tanimlandi
- [ ] Reusable component'ler olusturuldu
- [ ] Her ekranin 4 state'i tasarlandi (loading, error, empty, success)
- [ ] Her ekran `get_screenshot()` ile gorsel dogrulandi
- [ ] `snapshot_layout(problemsOnly=true)` ile teknik kontrol yapildi
- [ ] Tutarlilik kontrol edildi (font, renk, spacing)
- [ ] Responsive varyantlar dusunuldu (mobile, tablet, desktop)
- [ ] Handoff dokumani hazirlandi
