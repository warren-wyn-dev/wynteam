import Link from "next/link";

import { foodLegalPublication, foodLegalReady, type FoodLegalDocument } from "@/lib/food-legal";

import styles from "./food-legal-page.module.css";

export function FoodLegalPage({ document }: { document: FoodLegalDocument }) {
  return (
    <main className={styles.page}>
      <div className={styles.content}>
        <Link className={styles.back} href="/food/signup">← กลับไปสมัคร ZOKY</Link>
        <article className={styles.document}>
          <header className={styles.header}>
            <p className={styles.brand}>ZOKY</p>
            <h1>{document.title}</h1>
            <p>{document.description}</p>
            <p className={styles.date}>{foodLegalReady ? `มีผลตั้งแต่ ${foodLegalPublication.effectiveDate}` : "ฉบับร่างสำหรับตรวจสอบก่อนเผยแพร่"}</p>
          </header>

          {!foodLegalReady ? (
            <aside className={styles.notice} aria-label="สถานะเอกสาร">
              <strong>ฉบับร่าง ยังไม่มีผลบังคับใช้</strong>
              <p>เอกสารนี้อยู่ระหว่างยืนยันข้อมูลผู้ให้บริการ ช่องทางติดต่อ และอนุมัติเนื้อหาก่อนนำไปใช้จริง</p>
            </aside>
          ) : null}

          <nav className={styles.contents} aria-label="สารบัญ">
            <strong>สารบัญ</strong>
            {document.sections.map((section) => <a key={section.id} href={`#${section.id}`}>{section.title}</a>)}
            <a href="#operator">ข้อมูลผู้ให้บริการและช่องทางติดต่อ</a>
          </nav>

          {document.sections.map((section) => (
            <section key={section.id} id={section.id} className={styles.section}>
              <h2>{section.title}</h2>
              {section.paragraphs.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
              {section.items ? <ul>{section.items.map((item) => <li key={item}>{item}</li>)}</ul> : null}
            </section>
          ))}

          <section id="operator" className={styles.section}>
            <h2>ข้อมูลผู้ให้บริการและช่องทางติดต่อ</h2>
            {foodLegalReady ? (
              <>
                <p>ผู้ให้บริการและผู้ควบคุมข้อมูลส่วนบุคคล: {foodLegalPublication.operatorName}</p>
                <p>ที่อยู่ติดต่อ: {foodLegalPublication.contactAddress}</p>
                <p>อีเมล: <a href={`mailto:${foodLegalPublication.contactEmail}`}>{foodLegalPublication.contactEmail}</a></p>
                <p>เมื่อติดต่อเรื่องออเดอร์ โปรดระบุเลขคำสั่งซื้อและปัญหาที่พบ หากเป็นปัญหาการเตรียมหรือจัดส่งอาหาร สามารถติดต่อร้านผ่านข้อมูลติดต่อที่แสดงในบริการได้ด้วย</p>
              </>
            ) : <p>ข้อมูลผู้ให้บริการและช่องทางติดต่อสำหรับการใช้สิทธิอยู่ระหว่างยืนยัน จะแสดงในฉบับที่ได้รับอนุมัติก่อนมีผลใช้จริง</p>}
          </section>
        </article>
        <footer className={styles.footer}>
          <Link href={document.path === "/food/terms" ? "/food/privacy" : "/food/terms"}>
            {document.path === "/food/terms" ? "อ่านนโยบายความเป็นส่วนตัว" : "อ่านข้อกำหนดการใช้งาน"}
          </Link>
          <Link href="/food/login">เข้าสู่ระบบ ZOKY</Link>
        </footer>
      </div>
    </main>
  );
}
