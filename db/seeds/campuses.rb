# db/seeds/campuses.rb
# Idempotent seed of public Hysan Junior campuses (name, phone, location).
# Source: https://www.hysanjunior.com/campuses — photos left empty for Admin upload.

puts "🌱 Seeding campuses..."

campuses = [
  {
    code: "YGN_TIMECITY",
    name: "Yangon (TimeCity) Campus",
    phone: "09444440120",
    location: "Times City၊ Shop House No. 215 ၊ ဟံသာဝတီလမ်း၊ ကမာရွတ်မြို့နယ်၊ ရန်ကုန်။ နာရီစင်ကြီးနား၊ Teadot အပေါ်ထပ် (၂)လွှာ။"
  },
  {
    code: "YANKIN",
    name: "Yankin Campus",
    phone: "09943343332",
    location: "အမှတ် (၁၁၂) ၊ အောင်ဇေယျလမ်း ၊ ရွှေမိုးကောင်းကွန်ဒို၊ ရန်ကင်းမြို့နယ် ၊ Tower - B (Mezzanine)."
  },
  {
    code: "MDY_MGL",
    name: "Mandalay Campus (MGL)",
    phone: "09443999922",
    location: "73လမ်း 106*107ကြား Mingalar Mandalay (New Ocean),Block 1, Unit 13 ချမ်းမြသာစည်မြို့နယ် မန္တလေးမြို့။"
  },
  {
    code: "MYAWADDY",
    name: "Myawaddy Campus",
    phone: "09690309056",
    location: "NBLC Private School အမှတ် (၁၁) အောင်မြေရွှေဘုံလမ်း ၊ အမှတ် (၄) ရပ်ကွက် ၊ မြဝတီမြို့"
  },
  {
    code: "LASHIO",
    name: "Lashio Campus",
    phone: "0966470875",
    location: "ရပ်ကွက် (၁) ၊ ဗျူဟာလမ်း၊ အိမ်အမှတ် (၃) ၊ လားရှိုးမြို့။"
  },
  {
    code: "NAYPYITAW",
    name: "NayPhiTaw Campus",
    phone: "09400144306",
    location: "ရာဇသိင်္ဂလမ်းမကြီးဘေး ကံကော်ဝိုင်းအနီး Hotel Ace, ဒက္ခိဏသီရိမြို့နယ်၊ နေပြည်တော်"
  },
  {
    code: "MAWLAMYINE",
    name: "Mawlamyine Campus",
    phone: "09986002899",
    location: "အမှတ် ၄၅ ၊ ချမ်းအေးစုလမ်း၊ တောင်ဝိုင်း၊ စျေးကြိုရပ် (စျေးကြိုတော်ကူးကျောင်းတိုက်ဘေးလမ်း)၊ မော်လမြိုင်မြို့။"
  },
  {
    code: "TAUNGGYI",
    name: "Taunggyi Campus",
    phone: "09447307074",
    location: "98A ဇောတိကလမ်းသွယ်(2)နှင့် သီရိမင်္ဂလာလမ်းတောင့်ကန်ရှေ့ရပ်ကွက်၊ တောင်ကြီးမြို့။"
  },
  {
    code: "HPA_AN",
    name: "Hpa An Campus",
    phone: "09400688860",
    location: "ပိတောက်လမ်းနှင့်ကမ်းနားလမ်းထောင့်၊ အမှတ် ၄ ရပ်ကွက်၊ ဘားအံမြို့။"
  },
  {
    code: "PYIN_OO_LWIN",
    name: "Pyin OO Lwin Campus",
    phone: "09267857514",
    location: "အမှတ်(၈၆)၊၄၃လမ်း၊(၈)ကွက်၊၄၃လမ်း ၊မြို့လယ်ရွှေစည်းခုံကျောင်းတိုက်နှင့် snow queen private school အနီး၊ပြင်ဦးလွင်မြို့။"
  },
  {
    code: "NORTH_DAGON",
    name: "North Dagon Campus",
    phone: "09266900530",
    location: "သခင်အုန်းခင်လမ်း ၂၈ ရပ်ကွက်,မြောက်ဒဂုံမြို့နယ်။"
  },
  {
    code: "TACHILEIK",
    name: "Tarchilake Campus",
    phone: "09265972529",
    location: "ဆန်ဆိုင်း (က) ပုံလို့လမ်း အမှတ် 7/30 အခန်းနံပါတ် 4/5 တာချီလိတ်မြို့။"
  },
  {
    code: "THINGANGYUN",
    name: "Thingangyun Campus",
    phone: "09788930049",
    location: "အမှတ် ၉၉၁ - သုမင်္ဂလာလမ်းပေါ်၊ ရတနာလမ်းအနီး ၊ (၁၆)ပိုင်း (၁)ရပ်ကွက်၊ သင်္ဃန်းကျွန်းမြို့နယ်။"
  },
  {
    code: "MDY_ATM",
    name: "Mandalay Campus (ATM)",
    phone: "09440103237",
    location: "27 လမ်းနဲ့ 63x64ကြား၊နန်းရှေ့ အောင်တော်မူ၊ ချမ်းအေးသာစံမြို့နယ်၊ မန္တလေးမြို့။"
  },
  {
    code: "INSEIN",
    name: "Insein Campus",
    phone: "09756859479",
    location: "Address - No.153B ၊ ရွှေဝါ(၂)လမ်း ၊ မြို့သစ်(ဂ)ရပ်ကွက်၊ အင်းစိန်မြို့နယ် ၊ ရန်ကုန်မြို့။"
  },
  {
    code: "ONLINE",
    name: "Online",
    phone: "09403416332",
    location: "Zoom & GrapeSEED Connect(online)"
  }
]

campuses.each do |row|
  campus = Campus.find_or_initialize_by(name: row[:name])
  campus.assign_attributes(
    code: row[:code],
    phone: row[:phone],
    location: row[:location],
    status: CampusConstants::Status::ACTIVE
  )
  campus.save!
end

puts "✅ #{campuses.size} campuses ready (#{Campus.kept.count} kept campuses total)"
