import Foundation

struct ThaiMedicineEntry {
    let name: String
    let aliases: [String]
    let generic: String
    let form: String
}

enum ThaiMedicineCatalog {
    static let all: [ThaiMedicineEntry] = [
        .init(name: "Sara", aliases: ["ซาร่า", "sara"], generic: "paracetamol", form: "tablet"),
        .init(name: "Tylenol", aliases: ["tylenol"], generic: "paracetamol", form: "tablet"),
        .init(name: "Paracetamol", aliases: ["พาราเซตามอล", "acetaminophen", "para"], generic: "paracetamol", form: "tablet"),
        .init(name: "Tiffy", aliases: ["ทิฟฟี่", "tiffy"], generic: "paracetamol chlorpheniramine", form: "tablet"),
        .init(name: "Decolgen", aliases: ["ดีคอลเจน", "decolgen"], generic: "paracetamol", form: "tablet"),
        .init(name: "Stream", aliases: ["สตรีม", "stream"], generic: "paracetamol", form: "tablet"),
        .init(name: "Boska", aliases: ["บอสก้า", "boska"], generic: "ibuprofen", form: "tablet"),
        .init(name: "Nurofen", aliases: ["นูโรเฟน", "nurofen"], generic: "ibuprofen", form: "tablet"),
        .init(name: "Brufen", aliases: ["บรูเฟน", "brufen"], generic: "ibuprofen", form: "tablet"),
        .init(name: "Ibuprofen", aliases: ["ไอบูโพรเฟน", "ibu"], generic: "ibuprofen", form: "tablet"),
        .init(name: "Aspirin", aliases: ["แอสไพริน", "asa"], generic: "acetylsalicylic acid", form: "tablet"),
        .init(name: "Disprin", aliases: ["ดิสพริน", "disprin"], generic: "acetylsalicylic acid", form: "tablet"),
        .init(name: "Amoxicillin", aliases: ["อะม็อกซิซิลลิน", "amoxil", "amoxy"], generic: "amoxicillin", form: "capsule"),
        .init(name: "Augmentin", aliases: ["ออคเมนติน", "augmentin"], generic: "amoxicillin clavulanate", form: "tablet"),
        .init(name: "Cloxacillin", aliases: ["คลอกซาซิลลิน", "cloxa"], generic: "cloxacillin", form: "capsule"),
        .init(name: "Cefalexin", aliases: ["เซฟาเลซิน", "keflex", "cephalexin"], generic: "cefalexin", form: "capsule"),
        .init(name: "Metronidazole", aliases: ["เมโทรนิดาโซล", "flagyl"], generic: "metronidazole", form: "tablet"),
        .init(name: "Omeprazole", aliases: ["โอเมพราโซล", "losec"], generic: "omeprazole", form: "capsule"),
        .init(name: "Losec", aliases: ["โลเสค", "losec"], generic: "omeprazole", form: "capsule"),
        .init(name: "Gaviscon", aliases: ["แกวิสคอน", "gaviscon"], generic: "alginate", form: "liquid"),
        .init(name: "Maalox", aliases: ["มาล็อกซ์", "maalox"], generic: "aluminum magnesium", form: "liquid"),
        .init(name: "Buscopan", aliases: ["บัสโคแพน", "buscopan"], generic: "hyoscine", form: "tablet"),
        .init(name: "Motilium", aliases: ["โมทิเลียม", "motilium"], generic: "domperidone", form: "tablet"),
        .init(name: "Domperidone", aliases: ["โดมเพอริโดน"], generic: "domperidone", form: "tablet"),
        .init(name: "Loratadine", aliases: ["ลอราทาดีน", "clarityne", "claritin"], generic: "loratadine", form: "tablet"),
        .init(name: "Clarityne", aliases: ["คลาริทีน", "clarityne"], generic: "loratadine", form: "tablet"),
        .init(name: "Cetirizine", aliases: ["เซทิริซีน", "zyrtec"], generic: "cetirizine", form: "tablet"),
        .init(name: "Chlorpheniramine", aliases: ["คลอเฟนิรามีน", "cpm"], generic: "chlorpheniramine", form: "tablet"),
        .init(name: "Dimetapp", aliases: ["ไดเมทับ", "dimetapp"], generic: "brompheniramine", form: "liquid"),
        .init(name: "Bisolvon", aliases: ["ไบซอลวอน", "bisolvon"], generic: "bromhexine", form: "tablet"),
        .init(name: "Robitussin", aliases: ["โรบิทัสซิน", "robitussin"], generic: "dextromethorphan", form: "liquid"),
        .init(name: "Dextromethorphan", aliases: ["เด็กซ์โทรเมทอร์แฟน", "dm"], generic: "dextromethorphan", form: "liquid"),
        .init(name: "Salbutamol", aliases: ["ซัลบูทามอล", "ventolin"], generic: "salbutamol", form: "inhaler"),
        .init(name: "Ventolin", aliases: ["เวนโทลิน", "ventolin"], generic: "salbutamol", form: "inhaler"),
        .init(name: "Berodual", aliases: ["บีโรดูอัล", "berodual"], generic: "ipratropium fenoterol", form: "inhaler"),
        .init(name: "Prednisolone", aliases: ["เพรดนิโซโลน", "pred"], generic: "prednisolone", form: "tablet"),
        .init(name: "Dexamethasone", aliases: ["เดกซาเมทาโซน", "dexa"], generic: "dexamethasone", form: "tablet"),
        .init(name: "Metformin", aliases: ["เมทฟอร์มิน", "glucophage"], generic: "metformin", form: "tablet"),
        .init(name: "Amlodipine", aliases: ["แอมโลดิพีน", "norvasc"], generic: "amlodipine", form: "tablet"),
        .init(name: "Losartan", aliases: ["โลซาร์แทน", "cozaar"], generic: "losartan", form: "tablet"),
        .init(name: "Atorvastatin", aliases: ["อะทอร์วาสแตติน", "lipitor"], generic: "atorvastatin", form: "tablet"),
        .init(name: "Simvastatin", aliases: ["ซิมวาสแตติน", "zocor"], generic: "simvastatin", form: "tablet"),
        .init(name: "Vitamin C", aliases: ["วิตามินซี", "ascorbic", "vit c"], generic: "ascorbic acid", form: "tablet"),
        .init(name: "Vitamin B Complex", aliases: ["วิตามินบี", "b complex", "becozyme"], generic: "vitamin b", form: "tablet"),
        .init(name: "Calcium", aliases: ["แคลเซียม", "caltrate"], generic: "calcium", form: "tablet"),
        .init(name: "ORS", aliases: ["โออาร์เอส", "oral rehydration", "electrolyte"], generic: "oral rehydration salts", form: "powder"),
        .init(name: "Betadine", aliases: ["เบตาดีน", "betadine", "povidone"], generic: "povidone iodine", form: "liquid"),
        .init(name: "Bactroban", aliases: ["แบคโทรแบน", "bactroban", "mupirocin"], generic: "mupirocin", form: "cream"),
        .init(name: "Hydrocortisone", aliases: ["ไฮโดรคอร์ติโซน", "hc cream"], generic: "hydrocortisone", form: "cream"),
        .init(name: "Diclofenac", aliases: ["ไดโคลฟีแนค", "voltarol", "voltaren"], generic: "diclofenac", form: "tablet"),
        .init(name: "Mefenamic acid", aliases: ["กรดเมฟีนามิก", "ponstan"], generic: "mefenamic acid", form: "capsule"),
        .init(name: "Ponstan", aliases: ["พอนสแตน", "ponstan"], generic: "mefenamic acid", form: "capsule")
    ]
}
