export type ReactivationLanguage = "th" | "en";

export type ReactivationMessage = {
  title: string;
  body: string;
};

export function reactivationMessage(
  stage: number,
  language: ReactivationLanguage,
): ReactivationMessage {
  const safeStage = Number.isInteger(stage) && stage > 0 ? stage : 1;

  if (language === "en") {
    if (safeStage === 1) {
      return {
        title: "Welcome to WYNOS 👋",
        body: "Your account is ready. Come in and get started.",
      };
    }
    if (safeStage === 2) {
      return {
        title: "Come see WYNOS 👀",
        body: "There is more to explore and make your profile yours.",
      };
    }
    if (safeStage === 3) {
      return {
        title: "WYNOS is still here for you ✨",
        body: "Come back and discover something new.",
      };
    }

    const weekly = [
      {
        title: "Something new may be waiting on WYNOS",
        body: "Come take a look.",
      },
      {
        title: "Come back to WYNOS 👋",
        body: "Your profile is ready whenever you are.",
      },
      {
        title: "Time to explore WYNOS",
        body: "See what is happening.",
      },
    ] as const;
    return weekly[(safeStage - 4) % weekly.length];
  }

  if (safeStage === 1) {
    return {
      title: "ยินดีต้อนรับสู่ WYNOS 👋",
      body: "บัญชีของคุณพร้อมแล้ว เข้ามาเริ่มต้นใช้งานกันได้เลย",
    };
  }
  if (safeStage === 2) {
    return {
      title: "แวะมาดู WYNOS กัน 👀",
      body: "มีพื้นที่ใหม่ ๆ ให้คุณสำรวจและเริ่มสร้างโปรไฟล์ของคุณ",
    };
  }
  if (safeStage === 3) {
    return {
      title: "WYNOS ยังรอคุณอยู่นะ ✨",
      body: "กลับมาเริ่มต้นและค้นหาสิ่งที่น่าสนใจสำหรับคุณ",
    };
  }

  const weekly = [
    {
      title: "มีอะไรใหม่ให้ค้นพบบน WYNOS",
      body: "แวะกลับมาดูกัน",
    },
    {
      title: "กลับมาเจอกันที่ WYNOS 👋",
      body: "โปรไฟล์ของคุณพร้อมให้เริ่มต้นเสมอ",
    },
    {
      title: "ถึงเวลาสำรวจ WYNOS แล้ว",
      body: "เข้ามาดูว่าโลกของ WYNOS มีอะไรบ้าง",
    },
  ] as const;
  return weekly[(safeStage - 4) % weekly.length];
}
