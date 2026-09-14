import { readFileSync, writeFileSync } from "node:fs";

function replaceOnce(source, oldText, newText, label) {
  const first = source.indexOf(oldText);
  if (first < 0) throw new Error(`Missing patch target: ${label}`);
  if (source.indexOf(oldText, first + oldText.length) >= 0) throw new Error(`Ambiguous patch target: ${label}`);
  return source.slice(0, first) + newText + source.slice(first + oldText.length);
}

const composerPath = "web/components/beta4-composer.tsx";
let composer = readFileSync(composerPath, "utf8");
composer = replaceOnce(composer, "  Lock,\n  Star,", "  Lock,\n  Plus,\n  Star,", "Plus import");
composer = replaceOnce(
  composer,
  `  const hasContent = caption.trim().length > 0 || files.length > 0 || pollOptions.some((value) => value.trim().length > 0);`,
  `  const hasContent = caption.trim().length > 0 || files.length > 0 || pollOptions.some((value) => value.trim().length > 0);\n  const SelectedAudienceIcon = audienceOptions.find((item) => item.value === audience)?.icon ?? Globe2;`,
  "selected audience icon",
);
composer = replaceOnce(
  composer,
  `<button className="beta4-audience-chip" type="button" disabled={busy} onClick={() => setAudienceOpen(true)}><Globe2 size={14} /><span>{audienceLabel(audience)}</span><ChevronDown size={13} /></button>`,
  `<button className="beta4-audience-chip" type="button" disabled={busy} onClick={() => setAudienceOpen(true)}><SelectedAudienceIcon size={14} /><span>{audienceLabel(audience)}</span><ChevronDown size={13} /></button>`,
  "dynamic audience chip icon",
);
composer = replaceOnce(
  composer,
  `previews.length ? <><div className="beta4-image-strip">{previews.map((url, index) => <div className={\`beta4-image-preview ratio-\${aspectRatio.replace(":", "-")}\`} key={url}><img src={url} alt="" /><button type="button" aria-label={\`ลบรูปที่ \${index + 1}\`} onClick={() => setFiles((current) => current.filter((_, itemIndex) => itemIndex !== index))}><X size={16} /></button></div>)}</div><div className="beta4-ratio-chips" role="group" aria-label="อัตราส่วนรูป">{(["original", "1:1", "4:5", "16:9"] as AspectRatioChoice[]).map((ratio) => <button className={aspectRatio === ratio ? "active" : ""} type="button" onClick={() => setAspectRatio(ratio)} key={ratio}>{ratio === "original" ? "ต้นฉบับ" : ratio}</button>)}</div></> : null`,
  `previews.length ? <><div className="beta4-image-strip">{previews.map((url, index) => <div className={\`beta4-image-preview ratio-\${aspectRatio.replace(":", "-")}\`} key={url}><img src={url} alt="" /><button type="button" aria-label={\`ลบรูปที่ \${index + 1}\`} onClick={() => setFiles((current) => current.filter((_, itemIndex) => itemIndex !== index))}><X size={13} /></button></div>)}</div><div className="beta4-ratio-chips" role="group" aria-label="อัตราส่วนรูป">{(["original", "1:1", "4:5", "16:9"] as AspectRatioChoice[]).map((ratio) => <button className={\`ratio-chip ratio-\${ratio.replace(":", "-")} \${aspectRatio === ratio ? "active" : ""}\`} aria-pressed={aspectRatio === ratio} type="button" onClick={() => setAspectRatio(ratio)} key={ratio}>{ratio === "original" ? "ต้นฉบับ" : ratio}</button>)}</div><div className="beta4-image-count">{files.length}/9</div></> : null`,
  "ratio chips and image count",
);
composer = replaceOnce(
  composer,
  `{pollOptions.map((value, index) => <label key={index}><span>{index + 1}</span><input maxLength={80} value={value} disabled={busy} onChange={(event) => updatePollOption(index, event.target.value)} placeholder={\`ตัวเลือก \${index + 1}\`} />{pollOptions.length > 2 ? <button type="button" aria-label={\`ลบตัวเลือก \${index + 1}\`} onClick={() => removePollOption(index)}><X size={15} /></button> : null}</label>)}`,
  `{pollOptions.map((value, index) => <label key={index}><input maxLength={80} value={value} disabled={busy} onChange={(event) => updatePollOption(index, event.target.value)} placeholder={\`ตัวเลือกที่ \${index + 1}\`} />{index >= 2 ? <button type="button" aria-label={\`ลบตัวเลือก \${index + 1}\`} onClick={() => removePollOption(index)}><X size={18} /></button> : null}</label>)}`,
  "poll option rows",
);
composer = replaceOnce(
  composer,
  `{pollOptions.length < 4 ? <button className="beta4-add-option" type="button" disabled={busy} onClick={addPollOption}>+ เพิ่มตัวเลือก</button> : null}`,
  `{pollOptions.length < 4 ? <button className="beta4-add-option" type="button" disabled={busy} onClick={addPollOption}><Plus size={18} />เพิ่มตัวเลือก</button> : null}`,
  "poll add option",
);
composer = composer.replaceAll("<ImagePlus size={22} />", "<ImagePlus size={24} />");
composer = composer.replaceAll("<Camera size={22} />", "<Camera size={24} />");
composer = composer.replaceAll("<BarChart3 size={22} />", "<BarChart3 size={24} />");
composer = replaceOnce(
  composer,
  `{audienceOptions.map((item) => { const Icon = item.icon; return <button className="beta4-audience-row" type="button" onClick={() => { setAudience(item.value); setAudienceOpen(false); }} key={item.value}><span className="beta4-audience-icon"><Icon size={18} /></span><span><strong>{item.label}</strong><small>{item.description}</small></span>{item.nested ? <ChevronRight size={18} /> : <i className={audience === item.value ? "selected" : ""} />}</button>; })}`,
  `{audienceOptions.map((item) => { const Icon = item.icon; return <button className="beta4-audience-row" type="button" onClick={() => { setAudience(item.value); setAudienceOpen(false); }} key={item.value}><span className="beta4-audience-icon"><Icon size={24} /></span><span><strong>{item.label}</strong><small>{item.description}</small></span>{item.nested ? <span className="beta4-audience-nested">{audience === item.value ? <i className="selected" /> : null}<ChevronRight size={22} /></span> : <i className={audience === item.value ? "selected" : ""} />}</button>; })}`,
  "audience trailing state",
);
writeFileSync(composerPath, composer);

const detailPath = "web/components/post-detail-route.tsx";
let detail = readFileSync(detailPath, "utf8");
detail = replaceOnce(
  detail,
  `<small>{relativeTimeTh(row.created_at)}{row.location ? \` · 📍 \${row.location}\` : ""}</small>`,
  `<small>{relativeTimeTh(row.created_at)}</small>`,
  "product override: no Check-in/location display",
);
writeFileSync(detailPath, detail);

const cssPath = "web/app/system-parity-final.css";
let css = readFileSync(cssPath, "utf8");
if (css.includes("WYN-158 pixel closure from direct Flutter source audit")) throw new Error("pixel closure already present");
css += `\n\n/* WYN-158 pixel closure from direct Flutter source audit. */\n/* Detail action counts stay graphite; only stateful icons change colour. */\n.flutter-detail-actions button { color: var(--graphite); }\n.flutter-detail-actions button svg { color: var(--ink); }\n.flutter-detail-actions button.like.active { color: var(--graphite); }\n.flutter-detail-actions button.like.active svg { color: #f44336; }\n.flutter-detail-actions button[aria-label="ยกเลิกรีโพสต์"] { color: var(--graphite); }\n.flutter-detail-actions button[aria-label="ยกเลิกรีโพสต์"] svg { color: var(--sapphire); }\n.flutter-detail-actions button[aria-label="นำออกจากที่บันทึก"] { color: var(--graphite); }\n.flutter-detail-actions button[aria-label="นำออกจากที่บันทึก"] svg { color: var(--ink); }\n.detail-activity-row strong { margin-left: 7px; }\n\n/* Flutter comment row: 44px tap targets and reply guide before the 32px avatar. */\n.detail-comment-reply { padding-left: 61px; }\n.detail-comment-reply::before { left: 52px; top: 12px; height: 44px; }\n.detail-comment-actions { min-height: 60px; overflow: visible; }\n.detail-comment-delete, .detail-comment-like { width: 44px; min-width: 44px; height: 44px; min-height: 44px; }\n.detail-comment-like { position: relative; overflow: visible; }\n.detail-comment-like > span { position: absolute; top: 43px; left: 0; width: 44px; color: var(--graphite); font-size: 13px; line-height: 1.2; text-align: center; }\n.detail-reply-banner { justify-content: flex-start; gap: 5px; }\n\n/* Flutter composer field: the 46px tint belongs to the text field only; Send is outside after a 2px gap. */\n.flutter-detail-composer-field { height: 48px; padding: 0; grid-template-columns: minmax(0,1fr) 48px; gap: 2px; border-radius: 0; background: transparent; }\n.flutter-detail-composer-field input { height: 46px; padding: 0 16px; border-radius: 24px; background: var(--surface-tint, #f1efe9); }\n.flutter-detail-composer-field button { width: 48px; height: 48px; }\n\n/* Create Drop image controls follow WYN-109 exact touch/shape metrics. */\n.beta4-image-preview > button { width: 23px; height: 23px; }\n.beta4-image-preview > button svg { width: 13px; height: 13px; }\n.beta4-ratio-chips { margin-top: 8px; gap: 8px; }\n.beta4-ratio-chips button { min-height: 44px; padding: 8px 12px; display: inline-flex; align-items: center; gap: 7px; border-color: var(--hairline); color: var(--graphite); }\n.beta4-ratio-chips button.active { border-color: var(--sapphire); color: var(--sapphire); font-weight: 600; }\n.beta4-ratio-chips button::before { content: ""; display: block; flex: 0 0 auto; border: 1px solid currentColor; border-radius: 2px; box-sizing: border-box; }\n.beta4-ratio-chips .ratio-original::before { width: 14px; height: 10.5px; }\n.beta4-ratio-chips .ratio-1-1::before { width: 14px; height: 14px; }\n.beta4-ratio-chips .ratio-4-5::before { width: 11.2px; height: 14px; }\n.beta4-ratio-chips .ratio-16-9::before { width: 14px; height: 7.875px; }\n.beta4-image-count { margin-top: 4px; color: var(--faint); font-size: 13px; line-height: 1.2; }\n\n/* Poll composer mirrors Flutter TextField rows rather than numbered card rows. */\n.beta4-poll-options label { min-height: 48px; display: grid; grid-template-columns: minmax(0,1fr) 44px; gap: 4px; border: 0; border-radius: 0; overflow: visible; }\n.beta4-poll-options label > span { display: none; }\n.beta4-poll-options input { height: 48px; padding: 0 12px; border: 1px solid var(--hairline); border-radius: 12px; background: var(--paper); font-size: 16px; }\n.beta4-poll-options input:focus { border-color: var(--sapphire); }\n.beta4-poll-options label > button { width: 44px; height: 48px; }\n.beta4-add-option { min-height: 44px; display: inline-flex; align-items: center; gap: 6px; }\n\n/* Bottom toolbar: Flutter _ToolbarIcon is 72px high, radius 18, 24px icon, 7px icon-label gap. */\n.beta4-toolbar-actions button { min-height: 72px; height: 72px; gap: 7px; border-radius: 18px; border-color: var(--hairline); background: var(--surface-tint, #f1efe9); color: var(--ink); font-size: 12.5px; font-weight: 500; }\n.beta4-toolbar-actions button svg { width: 24px; height: 24px; }\n.beta4-toolbar-actions button.active { border-color: rgb(27 58 107 / 20%); background: rgb(27 58 107 / 20%); color: var(--sapphire); }\n.beta4-toolbar-actions button:disabled { color: var(--faint); }\n\n/* Audience sheet mirrors Flutter ListTile layout: 16px sheet inset, plain 24px leading icons, no row separators. */\n.beta4-sheet:not(.beta4-drafts-sheet) { padding-left: 16px; padding-right: 16px; }\n.beta4-sheet:not(.beta4-drafts-sheet) .beta4-sheet-grip { width: 32px; margin-bottom: 16px; }\n.beta4-sheet:not(.beta4-drafts-sheet) > header { min-height: 44px; padding: 0; }\n.beta4-sheet:not(.beta4-drafts-sheet) > header strong { font-size: 16px; font-weight: 600; }\n.beta4-audience-row { min-height: 64px; padding: 4px 0; grid-template-columns: 40px minmax(0,1fr) auto; border: 0; }\n.beta4-audience-icon { width: 40px; height: 44px; display: grid; place-items: center start; border-radius: 0; background: transparent; }\n.beta4-audience-icon svg { width: 24px; height: 24px; }\n.beta4-audience-row strong { font-size: 15px; font-weight: 400; }\n.beta4-audience-row small { color: var(--graphite); font-size: 12px; line-height: 1.3; }\n.beta4-audience-row > i, .beta4-audience-nested > i { width: 22px; height: 22px; border: 1.5px solid var(--graphite); border-radius: 50%; box-sizing: border-box; }\n.beta4-audience-row > i.selected, .beta4-audience-nested > i.selected { border: 6px solid var(--sapphire); }\n.beta4-audience-nested { display: inline-flex; align-items: center; gap: 4px; color: var(--graphite); }\n`;
writeFileSync(cssPath, css);

const gatePath = "web/tests/browser/final-source-parity-gate.spec.ts";
let gate = readFileSync(gatePath, "utf8");
gate = replaceOnce(
  gate,
  `  expect(css).toContain("height: 46px");\n});`,
  `  expect(css).toContain("height: 46px");\n  expect(css).toContain("WYN-158 pixel closure from direct Flutter source audit");\n  expect(css).toContain("min-height: 72px");\n  expect(css).toContain("min-height: 44px");\n  expect(css).toContain("grid-template-columns: minmax(0,1fr) 48px");\n  expect(composer).toContain("ตัวเลือกที่");\n  expect(composer).toContain("SelectedAudienceIcon");\n  expect(detail).not.toContain("📍");\n});`,
  "final parity regression gate",
);
writeFileSync(gatePath, gate);

console.log("WYN-158 final pixel closure applied");
