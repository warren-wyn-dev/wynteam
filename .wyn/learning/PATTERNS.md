# Reusable Patterns

Pattern การเขียนโค้ด/ออกแบบ/ทดสอบที่พิสูจน์แล้วว่าใช้ได้ดีใน WYN

## รูปแบบ

```
### Pattern: ชื่อ
- บริบทที่ใช้:
- รายละเอียด:
- ตัวอย่าง (ถ้ามี):
```

## รายการ

### Pattern: Callback-to-parent-rebuild แทน Navigator เมื่อ child ต้องแจ้ง auth-state gate
- บริบทที่ใช้: หน้าจอที่ auth-state gate (เช่น `AuthGate`) render โดยตรง (ไม่ได้ผ่าน `Navigator.push`) แล้วต้องการแจ้งให้ gate เปลี่ยนไปแสดงหน้าอื่นหลังทำ side effect สำเร็จ (เช่น เขียนข้อมูลลง database ที่ไม่ได้ยิง auth event)
- รายละเอียด: อย่าให้ child widget เรียก `Navigator.push`/`pushReplacement` เพื่อ "ไปหน้าถัดไป" เอง เพราะจะสร้าง route ใหม่แทนที่ route ของ gate ทำให้ gate (และ state/subscription ของมัน) ถูกทำลายทิ้งโดยไม่ตั้งใจ ให้ gate ส่ง `VoidCallback` ลงไปให้ child เรียกแทน แล้ว callback นั้นแค่ `setState(() {})` บน gate เอง เพื่อให้ gate rebuild และตัดสินใจหน้าจอใหม่ด้วยตัวเอง (เหมือนที่มันทำอยู่แล้วปกติ)
- ตัวอย่าง: `UsernameSetupScreen` (WYN-002) รับ `required VoidCallback onUsernameSet` จาก `AuthGate` เรียกหลัง `setUsername()` สำเร็จ แทนที่จะ `Navigator.pushReplacement` ไป `HomeScreen` เอง — แก้ regression Critical ที่เคยเกิดขึ้นจริงตอนใช้ Navigator (ดู `.wyn/learning/MISTAKES.md` และ `.wyn/learning/LESSONS_LEARNED.md`)

### Pattern: อ่าน mutable state สดใหม่ในตัว async handler เสมอ ห้ามพึ่ง parameter/closure ที่ capture ไว้ตอน build
- บริบทที่ใช้: ปุ่มที่เรียก async operation (เช่น network call) แล้วมี optimistic UI update — โดยเฉพาะเมื่อ callback ถูกสร้างจาก closure ที่ผูกกับค่าตอน build (`onTapLike: () => _toggleLike(post)`)
- รายละเอียด: อย่าส่ง object ที่ mutable (เช่น `Post`) เป็น parameter ของ async handler โดยหวังว่ามันจะ "ทันสมัย" เสมอ — closure ผูกกับค่าตอน build ล่าสุดเท่านั้น ถ้าผู้ใช้กดปุ่มซ้ำเร็ว ๆ ก่อนหน้าจอ rebuild ทุก call จะเห็นค่าเดิมเหมือนกันหมด ให้ handler รับแค่ id (immutable, เสถียร) แล้วอ่าน state ปัจจุบันจาก field/list ของ State เองที่ต้นๆ method เสมอ ควบคู่กับ guard (`if (_isXxx) return;`) เป็นบรรทัดแรกสำหรับปุ่มที่ไม่ควรถูกเรียกซ้อนกันเลย (เช่น submit form)
- ตัวอย่าง: `PostDetailScreen._toggleLike()` (WYN-004) เขียนถูกต้องตั้งแต่แรก (`final previous = _post;` อ่านสดทุกครั้ง) ส่วน `FeedScreen._toggleLike()` เขียนผิด (รับ `Post` เป็น parameter) จนกลายเป็นบั๊ก Major ที่ QA รอบ 1 เจอ แก้โดยเปลี่ยนให้รับ `String postId` แล้ว mirror pattern ของ `PostDetailScreen` — ดู `.wyn/tasks/bugs/WYN-004-feed-and-post.md`

### Pattern: subclass concrete repository เพื่อทำ test double แทนการเพิ่ม interface ใหม่
- บริบทที่ใช้: ต้องเขียน widget/unit test ที่ต้องดักจับ argument ที่ส่งเข้า repository (เช่น `PostRepository`) แต่ repository นั้นเป็น concrete class ผูกกับ `SupabaseClient` ตรง ๆ ไม่มี abstract interface
- รายละเอียด: ถ้า class ไม่ได้ประกาศเป็น `final`/`sealed` สามารถสร้าง subclass ใน test file แล้ว `@override` เฉพาะ method ที่ยิง network ให้แค่บันทึกการเรียก/คืนค่าที่ต้องการแทนได้เลย ไม่ต้อง refactor เป็น `abstract class`/interface ทั้งระบบก่อน — เป็นการเพิ่ม testability ที่เล็กที่สุดและปลอดภัยที่สุด (ตรงตามกติกา AI Debug Engineer "แก้ไขด้วย fix ที่เล็กที่สุด")
- ตัวอย่าง: `RecordingPostRepository` (`app/test/support/recording_post_repository.dart`, WYN-004) — ใช้พิสูจน์บั๊ก double-tap ของ `FeedScreen`/`CreatePostScreen` ได้จริงแบบ dynamic

### Pattern: ปลอม signed-in Supabase session แบบ local-only สำหรับ widget test
- บริบทที่ใช้: widget ที่อ่าน `Supabase.instance.client.auth.currentUser` ตรง ๆ (ไม่ได้ inject มาทาง constructor) ทำให้ pump ใน widget test ไม่ได้เพราะ `Supabase.instance` ยังไม่ถูก initialize และไม่มี session จริง
- รายละเอียด: เรียก `SharedPreferences.setMockInitialValues({})` (mock platform channel ที่ `supabase_flutter` ใช้เก็บ session ในเครื่อง) ตามด้วย `Supabase.initialize(url:, publishableKey:)` แล้วปลอม session ผ่าน `Supabase.instance.client.auth.recoverSession(jsonEncode(sessionJson))` โดยตั้ง `expires_at` ไว้ไกลในอนาคต — `recoverSession` ยิง network เฉพาะตอน session หมดอายุเท่านั้น (ดูโค้ด gotrue), session ที่ยังไม่หมดอายุจะถูกรับทันทีแบบ local-only ไม่ต้องมี backend จริง
- ตัวอย่าง: `initFakeSupabaseSession()` (`app/test/support/fake_supabase_session.dart`, WYN-004) — ใช้ pump `FeedScreen` เต็มรูปแบบใน `feed_screen_test.dart` ได้เป็นครั้งแรก

### Pattern: `find.byType()`/`find.text()` มองไม่เห็น widget ที่อยู่นอก viewport ใน `ListView`/`Sliver` — ต้อง scroll เข้ามาก่อนเสมอ
- บริบทที่ใช้: widget test ที่ต้อง tap/ตรวจสอบ element ซึ่งอยู่ใน `ListView`/`CustomScrollView` ที่มี header สูงมาก (เช่น รูปภาพ 1:1 กว้างเท่าจอ) วางอยู่ก่อนหน้า
- รายละเอียด: `ListView(children: [...])` ดูเหมือนสร้าง widget ทุกตัวใน `children` ทันที (eager) แต่จริง ๆ แล้วใช้ `SliverList` ข้างใต้ ซึ่ง**mount เป็น Element เฉพาะ child ที่อยู่ในหรือใกล้ viewport เท่านั้น** (บวก cache extent เริ่มต้น ~250 logical pixel) — child ที่อยู่ไกลเกินจอ (เช่น หลัง header สูง 800px บน viewport ทดสอบ 600px) จะไม่ถูก mount เข้า Element tree เลย ทำให้ `find.byType()`/`find.text()`/`find.byWidgetPredicate()` หาไม่เจอ (คืนค่า 0 widget) **ทั้งที่โค้ด production ถูกต้องสมบูรณ์แบบ** — เป็นข้อจำกัดของการทดสอบ ไม่ใช่บั๊กจริง ถ้าไม่รู้จุดนี้จะเข้าใจผิดว่าโค้ดพัง ทั้งที่จริงแค่ยังไม่ได้ scroll ไปหา element นั้น
- วิธีแก้: เรียก `tester.scrollUntilVisible(finder, delta, scrollable: find.byType(Scrollable).first)` เพื่อ scroll ทีละนิดจนกว่า element เป้าหมายจะถูก mount แล้วค่อย `tester.ensureVisible(finder)` + `pumpAndSettle()` ก่อนอ่าน/tap มันจริง — อย่าพยายาม `find` element ที่อาจอยู่นอก viewport โดยไม่ scroll ก่อนเด็ดขาด
- ตัวอย่าง: `app/test/drop_comment_like_test.dart` (WYN-005) — เสียเวลา debug นานเพราะเข้าใจผิดว่าฟีเจอร์พัง ทั้งที่จริงแค่ comment ถูกดันไปไกลเกิน viewport จาก Drop Detail's รูปภาพสูง 800px ในสภาพแวดล้อมทดสอบ

### Pattern: สร้าง fake platform-interface implementation เมื่อ behavior สำคัญผูกกับ plugin ที่ไม่มี platform channel ในสภาพแวดล้อมทดสอบ
- บริบทที่ใช้: widget ใช้ Flutter plugin ที่พึ่ง platform channel จริง (เช่น `video_player`) ซึ่งใน `flutter test` (ไม่มี Android SDK/Xcode/emulator) จะไม่มี handler ให้เรียก ทำให้ method call ที่ไปถึง platform (เช่น `VideoPlayerController.initialize()`) throw `MissingPluginException` เสมอ
- รายละเอียด: ถ้า behavior ที่ต้อง test ไม่ได้ผูกกับความสำเร็จของ plugin (เช่น layout ยังคงถูกต้องแม้รูปโหลดไม่สำเร็จ) การยอมรับว่า "ทดสอบไม่ได้ในสภาพแวดล้อมนี้ ต้องพึ่ง code review" ก็เพียงพอ (ตัวอย่าง: `Image.network` ใน Drop) แต่ถ้า behavior ผูกกับความสำเร็จของ plugin โดยตรง (เช่น view count ที่เพิ่มเฉพาะตอนวิดีโอเล่นสำเร็จ, mute/volume ที่ถูก apply ไปยัง controller) การยอมรับแบบนั้นจะทำให้จุดสำคัญไม่มี automated test คุ้มครองเลย — คุ้มกว่าที่จะสร้าง fake implementation ของ platform interface ของ plugin นั้น (เช่น `extends VideoPlayerPlatform` แล้ว override `createWithOptions`/`videoEventsFor`/`setVolume`/ฯลฯ ให้ทำงานแบบ deterministic ไม่พึ่ง platform channel จริง) แล้วติดตั้งผ่าน `XxxPlatform.instance = FakeXxxPlatform()` ครั้งเดียวใน `setUpAll` ก่อน pump widget ใด ๆ ที่สร้าง controller ของ plugin นั้น
- จุดที่ต้องระวัง: ต้อง emit event (เช่น `VideoEvent.initialized`) **หลัง** จาก method ที่คืน stream กลับไปแล้ว (เช่น ผ่าน `Future(() { ... })`) ไม่ใช่ก่อน เพราะ caller (`VideoPlayerController.initialize()`) จะ `.listen()` stream นั้น **หลัง** เรียก method เสร็จ — emit ก่อนจะทำให้ event หายไปเพราะยังไม่มีใคร subscribe
- ตัวอย่าง: `app/test/support/fake_video_player_platform.dart` (WYN-006) — ทำให้ทดสอบ view-count recording และ mute/volume propagation ของ `PopFeedScreen` ได้จริงแบบ deterministic แทนที่จะยอมรับว่าทดสอบไม่ได้เหมือน `Image.network`
