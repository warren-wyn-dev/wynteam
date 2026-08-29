import React, { useState } from "react";
import { ChevronLeft, Camera } from "lucide-react";

/*
  WYNOS — Edit Profile.

  Token system (same as every other WYNOS screen):
  ink #12120F · paper #FAF9F6 · canvas #EDEBE5
  graphite #8A8880 · faint #C7C4BC · hairline #E8E6E0
  sapphire #1B3A6B — the one accent
  Fraunces — avatar initial + screen title · Inter — everything else

  What changed vs. the reference screenshot, and why:
  - "บันทึก" goes from a bright sky-blue full-width button (a color that
    doesn't exist anywhere else in the app) to the same sapphire button
    pattern used for every primary action elsewhere (Drop's "โพสต์", Create
    Club's "สร้าง Club"). One accent color, everywhere.
  - The three text fields (username, display name, bio) move into the same
    single-card container introduced in Create Club, instead of floating
    as separate full-width sections — same reasoning as there: the form
    reads as one contained unit instead of stretching down the page.
  - Avatar edit affordance changes from a plain black circle with a camera
    icon (high-contrast, slightly harsh against the rest of the palette)
    to a sapphire-ringed circle with a small paper-colored camera badge —
    matches the avatar-ring treatment used for every avatar in the app.
  - Save button is disabled (faint) until something has actually changed
    from the original values, same disabled/enabled pattern as Drop and
    Create Club, so you can't "save" a no-op edit.
  - Username field gets an "@" prefix rendered outside the editable text
    instead of typed inline, so it can't accidentally be deleted while
    editing.
*/

const FONT_SANS = "'Inter', sans-serif";
const FONT_SERIF = "'Fraunces', serif";

function Field({ label, value, onChange, placeholder, maxLength, helper, multiline, prefix }) {
  const Tag = multiline ? "textarea" : "input";
  const [focused, setFocused] = useState(false);
  return (
    <div className="pt-4">
      <label className="text-[13px]" style={{ color: "#12120F", fontFamily: FONT_SANS, fontWeight: 500 }}>
        {label}
      </label>
      <div className="flex items-baseline mt-2" style={{ borderBottom: "1px solid #E8E6E0", paddingBottom: 10 }}>
        {prefix && (
          <span className="text-[14.5px] mr-0.5" style={{ color: "#8A8880", fontFamily: FONT_SANS }}>
            {prefix}
          </span>
        )}
        <Tag
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          maxLength={maxLength}
          rows={multiline ? 3 : undefined}
          placeholder={placeholder}
          className="w-full bg-transparent outline-none text-[14.5px] resize-none"
          style={{ color: "#12120F", fontFamily: FONT_SANS }}
        />
      </div>
      <div
        className="flex justify-between overflow-hidden transition-all"
        style={{ maxHeight: focused ? 40 : 0, marginTop: focused ? 6 : 0, opacity: focused ? 1 : 0 }}
      >
        <span className="text-[11.5px]" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>
          {helper}
        </span>
        <span className="text-[11.5px] tabular-nums shrink-0 ml-2" style={{ color: "#C7C4BC", fontFamily: FONT_SANS }}>
          {value.length}/{maxLength}
        </span>
      </div>
    </div>
  );
}

export default function WynosEditProfile() {
  const original = { username: "sky_blue", displayName: "ZEN", bio: "" };
  const [username, setUsername] = useState(original.username);
  const [displayName, setDisplayName] = useState(original.displayName);
  const [bio, setBio] = useState(original.bio);

  const hasChanges =
    username !== original.username || displayName !== original.displayName || bio !== original.bio;

  return (
    <div className="w-full min-h-screen flex items-center justify-center py-10" style={{ background: "#EDEBE5" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Fraunces:wght@400;500;600&family=Inter:wght@400;500;600;700&display=swap');
      `}</style>

      <div
        className="relative w-full overflow-hidden"
        style={{
          maxWidth: 390,
          height: 844,
          background: "#FAF9F6",
          borderRadius: 44,
          boxShadow: "0 30px 80px rgba(18,18,15,0.22), 0 2px 8px rgba(18,18,15,0.08)",
        }}
      >
        {/* status bar */}
        <div className="flex items-center justify-between px-7 pt-3.5 pb-1" style={{ color: "#12120F" }}>
          <span className="text-[15px] font-semibold" style={{ fontFamily: FONT_SANS }}>18:47</span>
          <div className="flex items-center gap-1.5 text-[12px]" style={{ fontFamily: FONT_SANS }}>
            <span>5G</span>
            <div className="w-6 h-3 rounded-sm border relative" style={{ borderColor: "#12120F99" }}>
              <div className="absolute inset-0.5 rounded-[1px]" style={{ width: "70%", background: "#12120F" }} />
            </div>
          </div>
        </div>

        {/* header */}
        <div className="grid items-center px-2 pt-2 pb-2" style={{ gridTemplateColumns: "40px 1fr 40px" }}>
          <button className="p-2 justify-self-start"><ChevronLeft size={22} strokeWidth={1.6} color="#12120F" /></button>
          <span className="justify-self-center" style={{ fontFamily: FONT_SERIF, fontWeight: 500, fontSize: 17, color: "#12120F" }}>
            แก้ไขโปรไฟล์
          </span>
          <span />
        </div>
        <div className="h-px" style={{ background: "#E8E6E0" }} />

        <div className="overflow-y-auto px-6" style={{ height: 844 - 40 - 44 }}>
          {/* avatar */}
          <div className="flex justify-center pt-6 pb-2">
            <button className="relative">
              <div className="relative flex items-center justify-center" style={{ width: 100, height: 100 }}>
                <div className="absolute inset-0 rounded-full" style={{ border: "1.5px solid #1B3A6B33" }} />
                <div
                  className="flex items-center justify-center rounded-full text-white"
                  style={{ width: 92, height: 92, background: "#8A6D3A", fontFamily: FONT_SERIF, fontSize: 36, fontWeight: 500 }}
                >
                  Z
                </div>
              </div>
              <div
                className="absolute bottom-0 right-0 w-8 h-8 rounded-full flex items-center justify-center"
                style={{ background: "#1B3A6B", border: "2px solid #FAF9F6" }}
              >
                <Camera size={14} strokeWidth={1.8} color="#FAF9F6" />
              </div>
            </button>
          </div>

          {/* fields card */}
          <div className="rounded-2xl mt-4 px-5" style={{ border: "1px solid #E8E6E0" }}>
            <Field
              label="ชื่อผู้ใช้"
              value={username}
              onChange={setUsername}
              maxLength={20}
              helper="ใช้ตัวอักษร a-z, 0-9 และ _ เท่านั้น (3-20 ตัวอักษร)"
              prefix="@"
            />
            <div className="h-px" style={{ background: "#E8E6E0" }} />
            <Field
              label="ชื่อแสดง"
              value={displayName}
              onChange={setDisplayName}
              maxLength={50}
              helper="1-50 ตัวอักษร"
            />
            <div className="h-px" style={{ background: "#E8E6E0" }} />
            <Field
              label="Bio"
              value={bio}
              onChange={setBio}
              maxLength={160}
              helper="คำอธิบายสั้น ๆ เกี่ยวกับตัวคุณ"
              multiline
            />
          </div>

          <div className="pt-6 pb-8">
            <button
              disabled={!hasChanges}
              className="w-full py-3.5 rounded-full text-[14px]"
              style={{
                background: hasChanges ? "#1B3A6B" : "#E8E6E0",
                color: hasChanges ? "#FAF9F6" : "#B7B4AC",
                fontFamily: FONT_SANS,
                fontWeight: 700,
              }}
            >
              บันทึก
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
