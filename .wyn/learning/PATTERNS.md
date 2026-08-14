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

### Pattern: `tester.pumpWidget()` ครั้งที่สองในเทสต์เดียวกันไม่รีเซ็ต State ถ้า widget type/ตำแหน่งเดิม — ต้องแยกเป็นคนละ `testWidgets` block
- บริบทที่ใช้: เทสต์ที่ต้องการเปรียบเทียบ 2 สถานการณ์ (เช่น "แสดงปุ่มเมื่อดูโพสต์ของคนอื่น" กับ "ไม่แสดงปุ่มเมื่อดูโพสต์ของตัวเอง") แล้วพยายามเรียก `tester.pumpWidget(MaterialApp(home: SameScreenType(...)))` ซ้ำสองครั้งในเทสต์เดียวกันด้วยข้อมูลคนละชุด โดยหวังว่าครั้งที่สองจะเป็น widget ใหม่ทั้งหมด
- รายละเอียด: ถ้า widget type และตำแหน่งใน tree เดิม (ไม่มี `Key` ต่างกัน) Flutter จะไม่ unmount/mount element ใหม่ แต่จะเรียก `didUpdateWidget()` ของ State เดิมแทน (`initState()` **ไม่** ถูกเรียกซ้ำ) — ถ้า widget ไม่ได้ override `didUpdateWidget()` (เช่น `DropDetailScreen` ที่ตั้งค่า `late Drop _drop`/`bool? _isFollowing` ใน `initState()` เท่านั้น) ค่าพวกนี้จะค้างจากการ pump ครั้งแรก ไม่อัปเดตตาม `widget.drop`/`widget.followRepository` ใหม่เลย ทำให้เทสต์ fail ด้วยเหตุผลที่ดูเหมือนบั๊กในโค้ด production แต่จริง ๆ เป็นแค่ testing setup ผิด
- วิธีแก้: แยกแต่ละสถานการณ์เป็นคนละ `testWidgets(...)` block เสมอ (แต่ละ block ได้ element tree ใหม่จริงตั้งแต่ต้น) แทนที่จะพยายาม pump ซ้ำสองครั้งในบล็อกเดียว
- ตัวอย่าง: `app/test/drop_detail_screen_test.dart` (WYN-008) — เทสต์ Follow button self-guard เดิมพยายาม pump ทั้ง "การ์ดของคนอื่น" แล้วตามด้วย "การ์ดของตัวเอง" ในบล็อกเดียว พบว่า `_isFollowing`/`_drop` ค้างค่าเดิมจากการ pump ครั้งแรก แก้โดยแยกเป็น 2 `testWidgets` block

### Pattern: `tester.pump(duration)` ยาวครั้งเดียวข้ามหลาย `Timer` deadline พร้อมกัน จะไม่พิสูจน์ว่า timer ตัวก่อนหน้าถูก cancel จริงหรือไม่ — ต้องแยก pump เป็นช่วง ๆ ทีละ deadline
- บริบทที่ใช้: เทสต์ debounce ที่ต้องการพิสูจน์ว่าการพิมพ์ต่อเนื่องยกเลิก `Timer` ตัวก่อนหน้าจริง (ไม่ใช่แค่ปล่อยให้ delay เฉย ๆ) — เช่น `SearchScreen`'s debounce (WYN-009)
- รายละเอียด: `tester.pump(duration)` เดินเวลาปลอมไปข้างหน้าตาม `duration` แล้ว process timer/microtask ที่ถึงกำหนดทั้งหมด **ก่อน**จะ trigger การ build เพียงครั้งเดียวตอนจบ — ถ้า pump ครั้งเดียวยาวพอที่จะข้าม deadline ของหลาย `Timer` พร้อมกัน (เช่น timer ที่ควรถูก cancel แต่ไม่ได้ถูก cancel จริง กับ timer ตัวใหม่ที่ถูกสร้างทีหลัง) ทั้งสอง callback จะรันเรียงกันโดยไม่มี rebuild คั่นกลาง ทำให้ widget เห็นแค่ค่าสุดท้ายหลัง callback ตัวหลังสุดรัน — สถานการณ์ "cancel ถูกต้อง" กับ "ลืม cancel แต่ pump ยาวไปพอดี" จะให้ผลลัพธ์ที่ทดสอบแล้วเหมือนกัน ทำให้เทสต์ไม่จับบั๊กได้จริงแม้ลบโค้ด cancel ออก
- วิธีแก้: แยก `tester.pump(...)` เป็นช่วงสั้น ๆ ให้แต่ละ pump ข้ามแค่ deadline เดียวต่อครั้ง (บังคับให้เกิด rebuild จริงระหว่างแต่ละ timer) และเลือกคำค้นตัวกลางที่ "valid" พอจะเห็นผลต่างได้จริงถ้า timer นั้นไม่ถูก cancel (เช่นคำค้น 2 ตัวอักษรขึ้นไปที่ยิง query จริงถ้า fire ไม่ใช่คำสั้นเกินไปที่ fire แล้วก็ไม่เห็นผลต่างอะไร)
- ตัวอย่าง: `app/test/search_screen_test.dart` (WYN-009) — test แรกที่เขียนไว้ ("typing quickly...only fires one query") ผ่านแม้ลบ `_debounceTimer?.cancel()` ออกจริง เพราะ pump เดียวยาว 500ms ครอบทุก deadline พร้อมกัน เขียนใหม่ให้แยก pump ทีละ deadline แล้วพิสูจน์ red→green ได้จริง

### Pattern: test ที่เทียบ "ก่อน/หลัง" การกระทำหนึ่งอย่างต้องเช็คว่า RecordingXRepository (test double) เองจำลองผลของการกระทำนั้นจริงหรือไม่ ไม่งั้น test อาจ vacuous
- บริบทที่ใช้: test ที่ต้องการพิสูจน์ว่า UI *ไม่* เปลี่ยนตามการเปลี่ยนแปลงของ backend state บางอย่าง (เช่น "highlight ยังอยู่แม้ mark-as-read สำเร็จแล้ว") โดยเรียก method ฝั่ง repository (เช่น `markAllAsRead()`) แล้วเช็คว่า widget ยังแสดงผลเหมือนเดิม
- รายละเอียด: ถ้า `RecordingXRepository` (test double) ของ method นั้นเป็นแค่ "บันทึกว่าเรียกกี่ครั้ง" (`markAllAsReadCalls++`) โดยไม่ mutate ข้อมูลอื่นใดที่ widget ใช้ render (เช่นไม่แก้ `isRead` ของ object ที่ถูก fetch มาแล้ว) การกระทำนั้น "ไม่มีผลอะไรให้เห็น" อยู่แล้วในสภาพแวดล้อมทดสอบ ไม่ว่า production code จะ implement ถูกหรือผิดก็ตาม — ทำให้ test ที่ "เทียบก่อน/หลัง" กลายเป็น vacuous (ผ่านเสมอไม่ว่าโค้ดจะถูกหรือผิด) เพราะไม่มีอะไรเปลี่ยนแปลงจริงให้พิสูจน์ตั้งแต่ต้น
- วิธีแก้: แทนที่จะเทียบ "ก่อน/หลัง" การกระทำเดียวกัน ให้สร้างข้อมูลทดสอบที่มีทั้งสองสถานะอยู่พร้อมกันตั้งแต่แรก (เช่น notification 2 รายการ — unread 1 + read-แล้ว 1) แล้วเทียบว่า UI แสดงผลต่างกันถูกต้องตามสถานะเริ่มต้นของแต่ละรายการหรือไม่ — วิธีนี้พิสูจน์ mapping logic จริง (ไม่ใช่แค่ "ไม่มีอะไรพัง") และยังทำ red→green ได้จริงด้วยการจำลอง mapping ผิด (เช่น hardcode ค่าเป็น `false` เสมอ) แล้วดูว่า test จับได้จริงไหม
- ตัวอย่าง: `app/test/notification_list_screen_test.dart` (WYN-012) — test แรกที่เขียนไว้ ("keeps its highlight...") ใช้ notification เดียว (unread) เทียบ container.color ก่อน/หลัง `markAllAsRead()` ซึ่งไม่จับบั๊กได้จริงเพราะ `RecordingNotificationRepository.markAllAsRead()` ไม่ mutate list เดิมเลย เขียนใหม่ให้มี notification ผสม (unread 1 + read-แล้ว 1) เทียบ container.color ของทั้งคู่แยกกัน พิสูจน์ red→green ได้จริง
