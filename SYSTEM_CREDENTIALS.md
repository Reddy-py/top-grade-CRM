# TopGrade CRM — Official Parent & Student Credential Directory & Access Control Guide

> **System Version:** 2026.3 • **Database Engine:** Supabase PostgreSQL + Auth  
> **Total Active Students:** 73  
> **Total Registered Parent Accounts:** 129 (Personal PNG Emails & @parents.topgradeteacher.edu Portal Logins)  
> **Status:** Live & Synchronized

---

## 1. Security & RBAC Isolation Policies

### 🔒 Parent Role Isolation (`PARENT`)
1. **Child Privacy:** When a parent logs in, they **strictly and solely see their own children** linked by family name, phone number, and verified email address. Under no circumstances can a parent view or access records of another family's child.
2. **Course Syllabus Isolation:**
   - **Parent Dashboard:** Displays exclusively the courses enrolled by their child(ren).
   - **Courses & Curriculum Page (`/courses`):** Enforces a strict filter where only the specific course streams selected by their child(ren) are visible. All other school courses in the general catalog are hidden.
3. **Multi-Child Families:** Parents with multiple enrolled children (e.g., *Dhara Desai* with *Dhyana* and *Aarshiv*; *Lani Mercado* with *Kiron* and *Cara*; *Florence Buaku* with *Isabelle* and *Julia*) can switch between their children seamlessly in the parent portal.
4. **Dual Guardians / Secondary Parents:** Secondary parents with separate contact entries (e.g., *Sandeep Duggal* for *Deven*, *Conner Kuzniar* for *Ethan*, *Ulaysha Gibbs* for *Ulaysha*, *Vondeah Grant* for *Brooke*) can log in using their own credentials and access their family's child dossier and courses.

### 🎓 Student Role Isolation (`STUDENT`)
1. **Student Login Identifier:** Students can authenticate using either their official **Student Code** (e.g., `TG-STU-2026-5001`) or their student email (e.g., `jacob.5001@student.topgrade.edu`).
2. **Profile & Performance:** Students have view-only access to their own attendance, timetable schedule, academic reports, and syllabus.
3. **Course Curriculum:** Under `/courses`, students see **only their enrolled course stream(s)**.

---

## 2. Authentication Standards

| Role | Username / Login Identifier | Password | Access Rights |
| :--- | :--- | :--- | :--- |
| **Parent** | Personal Email from PNG *(e.g. `tanyeafowls@yahoo.com`)* **OR** Portal Email *(e.g. `parent.tanyea.fowls.5001@parents.topgrade.edu`)* | `Parent@TopGrade2026` | View linked children, child timetable, child course curriculum, fees, attendance |
| **Student** | Student Code *(e.g. `TG-STU-2026-5001`)* **OR** Student Email *(e.g. `jacob.5001@student.topgrade.edu`)* | `Student@TopGrade2026` | View self dossier, enrolled course syllabus, weekly timetable, attendance |

---

## 3. Master Parent & Student Credential Directory (73 Records)

| # | Student ID | Student Name | Grade & School | Selected Course | Student Login Email | Parent Name & Phone | Parent Login Email (PNG / Personal) | Parent Portal Email |
| :- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | `TG-STU-2026-3044` | **Pari Upadhyaya** | Grade 12 • Narayana Olympiad School | | `English` | `riaupadhyaya3@gmail.com` | Jignesh Upadhyaya (+1 3468228020) | `tglbiz101@gmail.com` | `—` |
| **2** | `TG-STU-2026-3632` | **Siva Reddy** | Grade 12 • Bhashyam High School | `AP Calculus` | `clashofclansreddy@gmail.com` | Venakat (+1 7780648562) | `sivareddy683970@gmail.com` | `parent.venakat.3632@parents.topgrade.edu` |
| **3** | `TG-STU-2026-4231` | **rajesh ganta** | Grade 12 • TopGrade Partner School | `General Academic Track` | `rajeshganta@gmail.com` | srinu (+1 1234567894) | `rajeshganta@gmail.com` | `parent.srinu.4231@parents.topgrade.edu` |
| **4** | `TG-STU-2026-5001` | **Jacob** | Grade 5 • Sablatura | `Reading Comp` | `jacob.5001@student.topgrade.edu` | Tanyea Fowls (+1 832 209 9729) | `tanyeafowls@yahoo.com` | `parent.tanyea.fowls.5001@parents.topgrade.edu` |
| **5** | `TG-STU-2026-5002` | **Kamauri Hunter** | Kindergarten • IL Texas | `Reading` | `kamauri.hunter.5002@student.topgrade.edu` | Angel Lewis (+1 832 322 2239) | `missyou1970@yahoo.com` | `parent.angel.lewis.5002@parents.topgrade.edu` |
| **6** | `TG-STU-2026-5003` | **Tierra Perry** | Grade 10 • Top Grade Academy | `General Track` | `tierra.perry.5003@student.topgrade.edu` | Tierra Perry Parent (+1 832 888 8512) | `—` | `parent.tierra.perry.5003@parents.topgrade.edu` |
| **7** | `TG-STU-2026-5004` | **Camila** | Grade 3 • Lahon elem, | `Reading` | `camila.5004@student.topgrade.edu` | DULCE Eduardo Garcia (+1 832 276 2098) | `gdulce955@gmail.com` | `parent.dulce.eduardo.garcia.5004@parents.topgrade.edu` |
| **8** | `TG-STU-2026-5005` | **Giselle** | Grade 4 • Rogers | `Afterschool` | `giselle.5005@student.topgrade.edu` | Elizabeth Guillory (+1 832 589 3676) | `guilloryea@gmail.com` | `parent.elizabeth.guillory.5005@parents.topgrade.edu` |
| **9** | `TG-STU-2026-5006` | **Leandro** | Grade 4 • Silverlake | `Afterschool` | `leandro.5006@student.topgrade.edu` | Esperanza garcia (+1 832 431 1633) | `esperanzagarciaovalle@gmail.com` | `parent.esperanza.garcia.5006@parents.topgrade.edu` |
| **10** | `TG-STU-2026-5007` | **Kiron Mercado** | Grade 4 • Silverlake | `Afterschool` | `kiron.5007@student.topgrade.edu` | Lani Mercado (+1 713 319 8985) | `lani.garrido@gmail.com` | `parent.lani.mercado.5007@parents.topgrade.edu` |
| **11** | `TG-STU-2026-5007-B` | **Cara Mercado** | Grade 2 • Silverlake | `Afterschool` | `cara.5007b@student.topgrade.edu` | Lani Mercado (+1 713 319 8985) | `lani.garrido@gmail.com` | `parent.lani.mercado.5007@parents.topgrade.edu` |
| **12** | `TG-STU-2026-5008` | **Evelyn** | Kindergarten • Silvercrest | `Afterschool` | `evelyn.5008@student.topgrade.edu` | Anna Jan (+1 626 808 2351) | `annasjan@gmail.com` | `parent.anna.jan.5008@parents.topgrade.edu` |
| **13** | `TG-STU-2026-5009` | **CJ** | Grade 3 • Top Grade Academy | `Reading` | `cj.5009@student.topgrade.edu` | Chad Williams (+1 904 226 8065) | `chad8404@gmail.com` | `parent.chad.williams.5009@parents.topgrade.edu` |
| **14** | `TG-STU-2026-5010` | **Ethan Kuzniar** | Grade 4 • Top Grade Academy | `STAAR` | `ethan.kuzniar.5010@student.topgrade.edu` | Yoselin Kuzniar (+1 832 344 7553) | `conner.skuzniar@gmail.com` | `parent.yoselin.kuzniar.5010@parents.topgrade.edu` |
| **15** | `TG-STU-2026-5012` | **Minh** | Kindergarten • Silverlake elem | `Afterschool` | `minh.5012@student.topgrade.edu` | Loan Nguyen (+1 281 617 9583) | `nloan969@gmail.com` | `parent.loan.nguyen.5012@parents.topgrade.edu` |
| **16** | `TG-STU-2026-5013` | **Tu Hyunh** | Grade 10 • Top Grade Academy | `General Track` | `tu.hyunh.5013@student.topgrade.edu` | Tu Hyunh Parent (+1 714 261 6170) | `tuhuynh0046@gmail.com` | `parent.tu.hyunh.5013@parents.topgrade.edu` |
| **17** | `TG-STU-2026-5014` | **Peyton** | Grade 5 • Rogers | `Afterschool` | `peyton.5014@student.topgrade.edu` | Alexis Merritt (+1 334 372 5625) | `megul41@gmail.com` | `parent.alexis.merritt.5014@parents.topgrade.edu` |
| **18** | `TG-STU-2026-5015` | **Uriel** | Grade 10 • Top Grade Academy | `STAAR prep` | `uriel.5015@student.topgrade.edu` | Claudette Fonndikum (+1 713 382 5195) | `—` | `parent.claudette.fonndikum.5015@parents.topgrade.edu` |
| **19** | `TG-STU-2026-5016` | **Samson Miller** | Kindergarten • Red Duke | `Afterschool` | `samson.miller.5016@student.topgrade.edu` | Selena Miller (+1 713 820 0880) | `selenademps@hotmail.com` | `parent.selena.miller.5016@parents.topgrade.edu` |
| **20** | `TG-STU-2026-5017` | **Logan Starks** | Grade 6 • Sam Jamison | `Math & Reading` | `logan.starks.5017@student.topgrade.edu` | Quinisha Starks (+1 229 854 1224) | `qunisha.starks1@gmail.com` | `parent.quinisha.starks.5017@parents.topgrade.edu` |
| **21** | `TG-STU-2026-5018` | **Joseph** | Going to 1st grade- • Top Grade Academy | `Summer camp & Math, writing, reading tutoring` | `joseph.5018@student.topgrade.edu` | Janice Perkins (+1 919 215 3437) | `deeutley@gmail.com` | `parent.janice.perkins.5018@parents.topgrade.edu` |
| **22** | `TG-STU-2026-5019` | **Sumay** | Grade 7 • Sablatura | `Writing skills` | `sumay.5019@student.topgrade.edu` | Minny Bhatty (+1 662 617 9073) | `minnybhatty@gmail.com` | `parent.minny.bhatty.5038@parents.topgrade.edu` |
| **23** | `TG-STU-2026-5020` | **Chirag** | Grade 11 • Dawson | `AP Physics` | `chirag.5020@student.topgrade.edu` | Prakash Motwani (+1 304 419 5289) | `cmotwani10@gmail.com` | `parent.prakash.motwani.5020@parents.topgrade.edu` |
| **24** | `TG-STU-2026-5022` | **Kris** | Grade 9 • Top Grade Academy | `Geometry` | `kris.5022@student.topgrade.edu` | Rekha Nair (+1 346 391 0006) | `nair.rekha11@gmail.com` | `parent.rekha.nair.5022@parents.topgrade.edu` |
| **25** | `TG-STU-2026-5023` | **Lydia Chaiban** | Kindergarten • Red Duke | `summer camp` | `lydia.5023@student.topgrade.edu` | Natalie Chaiban (+1 504 495 3594) | `n_pilotte@yahoo.com` | `parent.natalie.chaiban.5023@parents.topgrade.edu` |
| **26** | `TG-STU-2026-5023-B` | **Elias Chaiban** | Kindergarten • Red Duke | `summer camp` | `elias.5023b@student.topgrade.edu` | Natalie Chaiban (+1 504 495 3594) | `n_pilotte@yahoo.com` | `parent.natalie.chaiban.5023@parents.topgrade.edu` |
| **27** | `TG-STU-2026-5024` | **Saanvi Narula** | Grade 12 • Clear Creek HS | `College Essay workshop` | `saanvi.narula.5024@student.topgrade.edu` | Uma Narula (+1 346 546 9546) | `umanutritionist@gmail.com` | `parent.uma.narula.5024@parents.topgrade.edu` |
| **28** | `TG-STU-2026-5025` | **Christopher Habal** | Grade 12 • HPVA-High School of Performing & Visual Arts | `SAT prep, College Essay workshop` | `christopher.habal.5025@student.topgrade.edu` | Barbara Habal (+1 832 526 2483) | `barbarajaycacho@yahoo.com` | `parent.barbara.habal.5025@parents.topgrade.edu` |
| **29** | `TG-STU-2026-5026` | **Sky Zielinski** | Kindergarten • Massey Ranch | `Afterschool` | `sky.zielinski.5026@student.topgrade.edu` | Lexii Zielinski (+1 832 274 9851) | `alexisszielinski@gmail.com` | `parent.lexii.zielinski.5026@parents.topgrade.edu` |
| **30** | `TG-STU-2026-5027` | **Eric Penaloza** | Kindergarten • Mary Marek | `Afterschool` | `eric.5027@student.topgrade.edu` | marisol penaloza (+1 832 941 8419) | `marisol.maldonado96@icloud.com` | `parent.marisol.penaloza.5027@parents.topgrade.edu` |
| **31** | `TG-STU-2026-5027-B` | **Robert Mora** | Grade 6 • Nolan Ryan | `Afterschool` | `robert.mora.5027b@student.topgrade.edu` | marisol penaloza (+1 832 941 8419) | `marisol.maldonado96@icloud.com` | `parent.marisol.penaloza.5027@parents.topgrade.edu` |
| **32** | `TG-STU-2026-5028` | **Faith** | Grade 4 • Silverlake | `Afterschool` | `faith.5028@student.topgrade.edu` | Mili Chavez (+1 346 313 5879) | `pabloymili2023@gmail.com` | `parent.mili.chavez.5028@parents.topgrade.edu` |
| **33** | `TG-STU-2026-5029` | **Amir Douhdouh** | Grade 8 • Berry Miller | `Afterschool` | `amir.douhdouh.5029@student.topgrade.edu` | Chantha (+1 346 574 4701) | `chanthavorng@icloud.com` | `parent.chantha.5029@parents.topgrade.edu` |
| **34** | `TG-STU-2026-5030` | **Dhyana Desai** | Grade 2 • Glen York elem | `GT prep/ Math & Reading` | `dhyana.5030@student.topgrade.edu` | Dhara Desai (+1 713 894 4018) | `dhara.6n@gmail.com` | `parent.dhara.desai.5030@parents.topgrade.edu` |
| **35** | `TG-STU-2026-5030-B` | **Aarshiv Desai** | Pre-K • Glen York elem | `GT prep/ Math & Reading` | `aarshiv.5030b@student.topgrade.edu` | Dhara Desai (+1 713 894 4018) | `dhara.6n@gmail.com` | `parent.dhara.desai.5030@parents.topgrade.edu` |
| **36** | `TG-STU-2026-5031` | **Amisha** | Grade 7 • Berry Miller | `PAP Spanish` | `amisha.5031@student.topgrade.edu` | Rashmi Aggarwal (+1 713 855 9596) | `rashmi.esq@gmail.com` | `parent.rashmi.aggarwal.5031@parents.topgrade.edu` |
| **37** | `TG-STU-2026-5032` | **Deven** | Grade 11 • Dawson | `AP Chem , SAT prep` | `deven.5032@student.topgrade.edu` | Linda Duggal (+1 832 314 3624) | `duggalmd@aol.com` | `parent.linda.duggal.5032@parents.topgrade.edu` |
| **38** | `TG-STU-2026-5034` | **Noshi Gupta** | Grade 11 • Top Grade Academy | `General Track` | `noshi.5034@student.topgrade.edu` | Anvita Gupta (+1 312 497 0695) | `anvita512@gmail.com` | `parent.anvita.gupta.5034@parents.topgrade.edu` |
| **39** | `TG-STU-2026-5034-B` | **Kiaan Gupta** | Grade 9 • Top Grade Academy | `General Track` | `kiaan.5034b@student.topgrade.edu` | Anvita Gupta (+1 312 497 0695) | `anvita512@gmail.com` | `parent.anvita.gupta.5034@parents.topgrade.edu` |
| **40** | `TG-STU-2026-5035` | **Raina** | Grade 5 • Top Grade Academy | `Hindi` | `raina.5035@student.topgrade.edu` | Nitin Wadhwa (+1 832 754 8223) | `nwadhwa78@gmail.com` | `parent.nitin.wadhwa.5035@parents.topgrade.edu` |
| **41** | `TG-STU-2026-5036` | **Brandon** | Grade 3 • Top Grade Academy | `Math` | `brandon.5036@student.topgrade.edu` | Brandon Kimmons (+1 901 246 5376) | `kimmonscare@gmail.com` | `parent.brandon.kimmons.5036@parents.topgrade.edu` |
| **42** | `TG-STU-2026-5037` | **Vinoli** | Grade 5 • Top Grade Academy | `Reading Writing` | `vinoli.5037@student.topgrade.edu` | Kaushalya Amunugama (+1 573 308 5088) | `kaushalya.amunugama@gmail.com` | `parent.kaushalya.amunugama.5037@parents.topgrade.edu` |
| **43** | `TG-STU-2026-5038` | **Sumay** | Grade 6 • Top Grade Academy | `Writing` | `sumay.5038@student.topgrade.edu` | Minny Bhatty (+1 662 617 9073) | `minnybhatty@gmail.com` | `parent.minny.bhatty.5038@parents.topgrade.edu` |
| **44** | `TG-STU-2026-5039` | **Anushka** | Grade 12 • Dawson | `SAT prep` | `anushka.5039@student.topgrade.edu` | Ayan Monpara (+1 281 736 0945) | `monpara@gmail.com` | `parent.ayan.monpara.5039@parents.topgrade.edu` |
| **45** | `TG-STU-2026-5041` | **Kaleb Smith** | Grade 12 • Pearland HS | `SAT prep` | `kaleb.smith.5041@student.topgrade.edu` | Blake Johnson (+1 973 760 4734) | `mykix3@gmail.com` | `parent.blake.johnson.5041@parents.topgrade.edu` |
| **46** | `TG-STU-2026-5043` | **Serena** | Grade 9 • Turner | `Alge 1` | `serena.5043@student.topgrade.edu` | Serena Ayala (+1 832 607 0195) | `smayala79@yahoo.com` | `parent.serena.ayala.5043@parents.topgrade.edu` |
| **47** | `TG-STU-2026-5045` | **Hari Charan** | Grade 11 • Dawson | `SAT prep` | `hari.charan.5045@student.topgrade.edu` | Gayathri Sathiamoorthy (+1 617 959 3713) | `gayathri.sathiamoorthy@gmail.com` | `parent.gayathri.sathiamoorthy.5045@parents.topgrade.edu` |
| **48** | `TG-STU-2026-5046` | **Reshmika** | Grade 9 • Dawson | `General Track` | `reshmika.5046@student.topgrade.edu` | Bindu Aghari (+1 832 215 5432) | `—` | `parent.bindu.aghari.5046@parents.topgrade.edu` |
| **49** | `TG-STU-2026-5047` | **Nikhil** | Grade 12 • Shadow Creek | `SAT prep` | `nikhil.5047@student.topgrade.edu` | Shiva Marthy (+1 281 851 5873) | `shiva90@gmail.com` | `parent.shiva.marthy.5047@parents.topgrade.edu` |
| **50** | `TG-STU-2026-5048` | **Chaitanya Gundapaneni** | Grade 10 • Top Grade Academy | `General Track` | `chaitanya.gundapaneni.5048@student.topgrade.edu` | Chaitanya Gundapaneni Parent (+1 281 614 9093) | `chaitu900@gmail.com` | `parent.chaitanya.gundapaneni.5048@parents.topgrade.edu` |
| **51** | `TG-STU-2026-5049` | **Brooke** | Grade 8 • Berry Miller | `Math` | `brooke.5049@student.topgrade.edu` | Garrett Grant (+1 713 299 8351) | `vondeahgrant@yahoo.com` | `parent.garrett.grant.5049@parents.topgrade.edu` |
| **52** | `TG-STU-2026-5051` | **Ulaysha** | Grade 12 • Shadow Creek | `TSI prep` | `ulaysha.5051@student.topgrade.edu` | Elizabeth Osorio (+1 713 302 1264) | `ulayshagibbs@gmail.com` | `parent.elizabeth.osorio.5051@parents.topgrade.edu` |
| **53** | `TG-STU-2026-5053` | **Madison Carter** | Grade 6 • Sablatura | `Afterschool` | `madison.carter.5053@student.topgrade.edu` | Amy Carter (+1 832 816 4463) | `carterae2020@gmail.com` | `parent.amy.carter.5053@parents.topgrade.edu` |
| **54** | `TG-STU-2026-5054` | **Isabelle Buaku** | Grade 3 • Silvercrest | `Afterschool` | `isabelle.5054@student.topgrade.edu` | Florence Buaku (+1 734 709 1718) | `flossied@gmail.com` | `parent.florence.buaku.5054@parents.topgrade.edu` |
| **55** | `TG-STU-2026-5054-B` | **Julia Buaku** | Grade 6 • Rogers | `Afterschool` | `julia.5054b@student.topgrade.edu` | Florence Buaku (+1 734 709 1718) | `flossied@gmail.com` | `parent.florence.buaku.5054@parents.topgrade.edu` |
| **56** | `TG-STU-2026-5055` | **Abigail Rawls** | Grade 6 • Rogers | `Afterschool` | `abigail.rawls.5055@student.topgrade.edu` | Judith Rawls (+1 202 368 3012) | `jcothorn@gmail.com` | `parent.judith.rawls.5055@parents.topgrade.edu` |
| **57** | `TG-STU-2026-5056` | **Abi Bridger** | Grade 6 • Rogers | `Afterschool` | `abi.bridger.5056@student.topgrade.edu` | Yordana Bridger (+1 ) | `—` | `parent.yordana.bridger.5056@parents.topgrade.edu` |
| **58** | `TG-STU-2026-5057` | **Viviana** | Grade 2 • Silvercrest, | `Afterschool` | `viviana.5057@student.topgrade.edu` | Geraldine Raja (+1 716 464 0517) | `gerijosie@yahoo.com` | `parent.geraldine.raja.5057@parents.topgrade.edu` |
| **59** | `TG-STU-2026-5058` | **Nehemiah Pappan** | Grade 6 • Sablatura | `ESL` | `nehemiah.5058@student.topgrade.edu` | Soosan Pappan (+1 832 746 7799) | `soosanmathai@yahoo.com` | `parent.soosan.pappan.5058@parents.topgrade.edu` |
| **60** | `TG-STU-2026-5058-B` | **Bezaleel Pappan** | Grade 7 • PJHW | `ESL` | `bezaleel.5058b@student.topgrade.edu` | Soosan Pappan (+1 832 746 7799) | `soosanmathai@yahoo.com` | `parent.soosan.pappan.5058@parents.topgrade.edu` |
| **61** | `TG-STU-2026-5059` | **Kaliyah Morgan** | Grade 4 • Wilder elem | `Reading & Math` | `kaliyah.5059@student.topgrade.edu` | Lakeshia Morgan (+1 936 414 7009) | `—` | `parent.lakeshia.morgan.5059@parents.topgrade.edu` |
| **62** | `TG-STU-2026-5059-B` | **Kalena Morgan** | Grade 2 • Wilder elem | `Reading & Math` | `kalena.5059b@student.topgrade.edu` | Lakeshia Morgan (+1 936 414 7009) | `—` | `parent.lakeshia.morgan.5059@parents.topgrade.edu` |
| **63** | `TG-STU-2026-5060` | **Kayden Jones** | Grade 4 • The Imani school | `Math` | `kayden.jones.5060@student.topgrade.edu` | Chardae Evans (+1 346 319 9044) | `chardaeevans1@gmail.com` | `parent.chardae.evans.5060@parents.topgrade.edu` |
| **64** | `TG-STU-2026-5061` | **AmudhanMadhan Kumar** | Grade 12 • Dawson | `College Essay writing` | `amudhanmadhan.kumar.5061@student.topgrade.edu` | Brindha Madhan (+1 281 809 6351) | `brindha.biotek@gmail.com` | `parent.brindha.madhan.5061@parents.topgrade.edu` |
| **65** | `TG-STU-2026-5062` | **Sophie Smith** | Grade 9 • Turner | `Afterschool` | `sophie.5062@student.topgrade.edu` | Annie Smith (+1 832 275 5298) | `annieb@cgsfs.com` | `parent.annie.smith.5062@parents.topgrade.edu` |
| **66** | `TG-STU-2026-5062-B` | **Dahlia Smith** | Grade 5 • Rogers | `Afterschool` | `dahlia.5062b@student.topgrade.edu` | Annie Smith (+1 832 275 5298) | `annieb@cgsfs.com` | `parent.annie.smith.5062@parents.topgrade.edu` |
| **67** | `TG-STU-2026-5063` | **Chardaet Galvan** | Grade 10 • Top Grade Academy | `General Track` | `chardaet.galvan.5063@student.topgrade.edu` | Chardaet Galvan Parent (+1 713 858 5771) | `—` | `parent.chardaet.galvan.5063@parents.topgrade.edu` |
| **68** | `TG-STU-2026-5064` | **Evan Li** | Grade 10 • Dawson | `PAP Chemistry, PAP Alge 2` | `evan.li.5064@student.topgrade.edu` | Ke Li (+1 832 288 0435) | `ke.li@outlook.com` | `parent.ke.li.5064@parents.topgrade.edu` |
| **69** | `TG-STU-2026-5065` | **Micah** | Grade 7 • PJHS | `Reading, Handwriting` | `micah.5065@student.topgrade.edu` | Wes Murdoch (+1 832 712 3339) | `wesdmurdock@hotmail.com` | `parent.wes.murdoch.5065@parents.topgrade.edu` |
| **70** | `TG-STU-2026-5066` | **Ava** | Grade 10 • Pearland HS | `PAP Geometry` | `ava.5066@student.topgrade.edu` | Rosie Lopez (+1 832 879 7941) | `rosieflopez@yahoo.com` | `parent.rosie.lopez.5066@parents.topgrade.edu` |
| **71** | `TG-STU-2026-5067` | **Charlotte** | Grade 12 • Manvel HS | `Math` | `charlotte.5067@student.topgrade.edu` | Frank Fernandez (+1 713 823 6790) | `ftfern24@yahoo.com` | `parent.frank.fernandez.5067@parents.topgrade.edu` |
| **72** | `TG-STU-2026-5068` | **Charlie** | Grade 4 • Massey ranch | `Reading` | `charlie.5068@student.topgrade.edu` | Liz Rodwell (+1 401 743 9608) | `elizabethannrodwell@gmail.com` | `parent.liz.rodwell.5068@parents.topgrade.edu` |
| **73** | `TG-STU-2026-9717` | **harshith pabisetty** | Grade 12 • TopGrade Partner School | `Python Beginners & Logic` | `std-1788241892654@topgrade.edu` | sathish (+1 5818585656) | `std-1788241892654@topgrade.edu` | `parent.sathish.9717@parents.topgrade.edu` |

---

## 4. Secondary Parent / Dual-Guardian Accounts (Linked Families)

The following secondary parents and guardians share phone numbers or family ties with enrolled students and have dedicated login credentials to view their child's dossier and course tracks:

| # | Guardian Name | Login Email | Password | Phone | Linked Child | Child Student ID | Enrolled Course |
| :- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | **Sandeep Duggal** | `duggalmd@aol.com` | `Parent@TopGrade2026` | +1 832 314 3626 | **Deven** | `TG-STU-2026-5032` | `AP Chem , SAT prep` |
| **2** | **Conner Kuzniar** | `conner.skuzniar@gmail.com` | `Parent@TopGrade2026` | +1 713 208 0947 | **Ethan Kuzniar** | `TG-STU-2026-5010` | `STAAR` |
| **3** | **Chirag Motwani** | `cmotwani10@gmail.com` | `Parent@TopGrade2026` | +1 304 767 2676 | **Chirag** | `TG-STU-2026-5020` | `AP Physics` |
| **4** | **Vondeah Grant** | `vondeahgrant@yahoo.com` | `Parent@TopGrade2026` | +1 713 725 3665 | **Brooke** | `TG-STU-2026-5049` | `Math` |
| **5** | **Ulaysha Gibbs** | `ulayshagibbs@gmail.com` | `Parent@TopGrade2026` | +1 713 820 0792 | **Ulaysha** | `TG-STU-2026-5051` | `TSI prep` |
| **6** | **Chaitanya Gundapaneni** | `chaitu900@gmail.com` | `Parent@TopGrade2026` | +1 281 614 9093 | **Chaitanya Gundapaneni** | `TG-STU-2026-5048` | `SAT prep` |
| **7** | **Kirtida Monpara** | `parent.kirtida.monpara.5040@parents.topgrade.edu` | `Parent@TopGrade2026` | +1 781 353 1272 | **Anushka** | `TG-STU-2026-5039` | `SAT prep` |
| **8** | **Kaleb Smith (Parent Contact)** | `parent.kaleb.smith.5042@parents.topgrade.edu` | `Parent@TopGrade2026` | +1 908 340 2976 | **Kaleb Smith** | `TG-STU-2026-5041` | `SAT prep` |
| **9** | **Serena III** | `parent.serena.iii.5044@parents.topgrade.edu` | `Parent@TopGrade2026` | +1 979 900 7400 | **Serena** | `TG-STU-2026-5043` | `Algebra 1` |

---

## 5. Course Tracks & Normalized Catalog Mapping

Below is the cross-reference between PNG course names and TopGrade CRM catalog courses:

| PNG Course Name | Enrolled TopGrade Course Stream | Catalog Course Code | Category |
| :--- | :--- | :--- | :--- |
| **Reading Comp** | Reading Comprehension | `CRS-REA-101` | Language Arts & Reading |
| **Reading** | Reading Foundations / Comprehension | `CRS-REA-101` | Language Arts & Reading |
| **Afterschool** | After School Program | `CRS-AFT-101` | General Enrichment |
| **STAAR / STAAR prep** | STAAR Prep (Math & Reading) | `CRS-STR-101` | Test Preparation |
| **Math & Reading** | Math & Reading Foundations | `CRS-MR-101` | Academic Core |
| **Summer camp & Math, writing, reading tutoring** | Summer Camp & Academic Tutoring | `CRS-SMP-101` | Summer & Camps |
| **Writing skills / Writing** | Writing Skills & Handwriting | `CRS-WRT-101` | Language Arts & Reading |
| **AP Physics** | AP Physics 1 & C | `CRS-APP-101` | Advanced Placement (AP) |
| **Geometry** | High School Geometry Honors | `CRS-GEO-101` | High School Mathematics |
| **Summer camp** | Summer Camp & Academic Tutoring | `CRS-SMP-101` | Summer & Camps |
| **College Essay workshop** | College Essay Workshop & Writing | `CRS-CEW-101` | College Counseling |
| **SAT prep / SAT prep, College Essay** | SAT Prep & College Essay Workshop | `CRS-SAT-101`, `CRS-CEW-101` | Test Preparation |
| **GT prep/ Math & Reading** | GT Prep (Gifted & Talented) | `CRS-GTP-101`, `CRS-MR-101` | Accelerated & GT |
| **PAP Spanish** | PAP Spanish | `CRS-SPN-101` | World Languages |
| **AP Chem , SAT prep** | AP Chemistry & SAT Prep | `CRS-APC-101`, `CRS-SAT-101` | AP & Test Prep |
| **Hindi** | Hindi Language | `CRS-HIN-101` | World Languages |
| **Alge 1** | Algebra 1 & PAP Algebra 2 | `CRS-ALG-101` | Mathematics |
| **TSI prep** | TSI Prep | `CRS-TSI-101` | College Readiness |
| **ESL** | ESL (English as a Second Language) | `CRS-ESL-101` | Language Acquisition |

---

## 6. How Parents and Students Log In

1. Open the TopGrade CRM login screen.
2. **For Parents:**
   - Enter your personal email (e.g., `tanyeafowls@yahoo.com`) or your portal email (`parent.tanyea.fowls.5001@parents.topgrade.edu`).
   - Enter password: `Parent@TopGrade2026`.
   - Result: You will see your child's profile on the Parent Dashboard, and under the **Courses** tab you will only see their selected course stream (*Reading Comprehension*).
3. **For Students:**
   - Enter your Student Code (e.g., `TG-STU-2026-5001`) or your student email (`jacob.5001@student.topgrade.edu`).
   - Enter password: `Student@TopGrade2026`.
   - Result: You will see your own profile and enrolled course syllabus.

---
*Generated automatically by TopGrade CRM Enrollment & RBAC Synchronizer.*
