window.DATA = {
  user: { name: 'Mura', initials: 'MU' },
  schools: [
    { id: 's1', name: 'Kigali Modern Academy', desc: 'A demo school for exploring EduAI.', classes: [
      { id: 'c1', name: 'Primary 6 — English', grade: 'P6', joined: true },
      { id: 'c2', name: 'Primary 5 — Mathematics', grade: 'P5', joined: false },
    ] },
  ],
  languages: ['English', 'Kinyarwanda', 'Français'],
  tutorSamples: {
    'Explain photosynthesis simply': [
      { type: 'text', text: 'Photosynthesis is how plants turn sunlight into food.\n\nLeaves capture light energy, then combine it with water and carbon dioxide from the air to make **glucose** (sugar) — releasing oxygen as a byproduct.' },
      { type: 'example', title: 'Everyday example', body: 'Think of a leaf as a tiny solar-powered kitchen: sunlight is the power, water and CO2 are the ingredients, and glucose is the meal the plant "eats" to grow.' },
      { type: 'check', question: 'What gas do plants release during photosynthesis?', choices: ['Carbon dioxide', 'Oxygen', 'Nitrogen'], correctIndex: 1, explanation: 'Plants take in CO2 and release oxygen as a byproduct of making glucose.' },
      { type: 'followups', items: ['What is chlorophyll?', 'Why do leaves look green?'] },
    ],
    'Help me solve 2x + 5 = 11': [
      { type: 'text', text: 'Let\'s isolate **x** step by step.' },
      { type: 'example', title: 'Step-by-step', body: 'Subtract 5 from both sides: 2x = 6.\nDivide both sides by 2: x = 3.' },
      { type: 'check', question: 'What is x if 3x + 4 = 13?', choices: ['2', '3', '4'], correctIndex: 1, explanation: '3x = 9, so x = 3.' },
      { type: 'followups', items: ['Show me on paper', 'Try a harder equation'] },
    ],
    'What caused World War I?': [
      { type: 'text', text: 'World War I (1914–1918) was triggered by the assassination of Archduke Franz Ferdinand, but the deeper causes were **alliances, militarism, imperialism and nationalism** across Europe.' },
      { type: 'followups', items: ['Which countries were in each alliance?', 'How did it end?'] },
    ],
    'Why is the sky blue?': [
      { type: 'text', text: 'Sunlight looks white but contains all colours. Air molecules scatter shorter (blue) wavelengths far more than longer (red) ones — this is **Rayleigh scattering** — so blue light reaches your eyes from all directions.' },
      { type: 'followups', items: ['Why is the sunset orange?', 'Why is the ocean blue?'] },
    ],
  },
  lessons: {
    grades: ['Pre-primary', 'P1–P6', 'O-Level', 'A-Level', 'Exam prep'],
    items: [
      { id: 'l1', grade: 'P1–P6', subject: 'Mathematics', title: 'Fractions: adding like denominators', reb: true, downloaded: true },
      { id: 'l2', grade: 'P1–P6', subject: 'English', title: 'Building compound sentences', reb: true, downloaded: false },
      { id: 'l3', grade: 'P1–P6', subject: 'Science', title: 'The water cycle', reb: true, downloaded: true },
      { id: 'l4', grade: 'O-Level', subject: 'Biology', title: 'Cell structure & function', reb: true, downloaded: false },
      { id: 'l5', grade: 'O-Level', subject: 'Physics', title: "Newton's laws of motion", reb: true, downloaded: false },
      { id: 'l6', grade: 'A-Level', subject: 'Chemistry', title: 'Organic reaction mechanisms', reb: true, downloaded: false },
      { id: 'l7', grade: 'Exam prep', subject: 'Mathematics', title: 'REB National Exam: past paper drills', reb: true, downloaded: true },
      { id: 'l8', grade: 'Pre-primary', subject: 'Numeracy', title: 'Counting 1 to 20 with objects', reb: false, downloaded: false },
    ],
  },
  lessonBody: {
    l1: ['Fractions with the same denominator share equal-sized parts of a whole — so adding them only means adding the numerators.', 'For example, 2/5 + 1/5 = 3/5. The denominator (5) stays the same because the pieces are the same size; only count how many pieces you have.', 'Try it: 3/8 + 2/8 = ? Write your working in the margin and check it against the worked example on the right.'],
  },
  progress: {
    subjects: [
      { name: 'Mathematics', mastery: 78, color: 'brand' },
      { name: 'English', mastery: 64, color: 'success' },
      { name: 'Science', mastery: 52, color: 'warning' },
    ],
    streak: [true, true, true, false, true, true, false],
    examReadiness: 68,
    shared: true,
  },
  parent: {
    children: [
      { id: 'k1', name: 'Alice K.', grade: 'P6', initials: 'AK', minutes: 210, questions: 34, streak: 5, attention: ['Science — fractions of measurement'] },
      { id: 'k2', name: 'Jean P.', grade: 'P4', initials: 'JP', minutes: 96, questions: 12, streak: 2, attention: ['English — spelling'] },
    ],
    messages: [
      { from: 'Mrs. Uwase (Class teacher)', text: 'Alice did great on this week\'s fractions quiz — keep encouraging 15 minutes of practice a night.', time: 'Mon' },
      { from: 'You', text: 'Thank you! We\'ll keep it up. Is there weekend homework?', time: 'Mon', me: true },
      { from: 'Mrs. Uwase (Class teacher)', text: 'Yes — REB worksheet 4, shared in Lessons.', time: 'Tue' },
    ],
    plan: { school: 'Kigali Modern Academy', tier: 'Growth', seats: 640, renews: '1 Sep 2026' },
    topups: [
      { label: 'Small top-up', sessions: 20, price: 500 },
      { label: 'Family pack', sessions: 60, price: 1200 },
      { label: 'Term pack', sessions: 150, price: 2500 },
    ],
  },
  admin: {
    plan: { tier: 'Growth', pricePerSeat: 1500, seatsUsed: 640, seatsTotal: 750, renews: '1 Sep 2026' },
    tiers: [
      { name: 'Starter', price: 900, seats: 'Up to 150 students', features: ['AI Tutor', 'Lessons library', 'Offline access'] },
      { name: 'Growth', price: 1500, seats: 'Up to 800 students', features: ['Everything in Starter', 'Stylus workbook', 'Parent reports'], reco: true },
      { name: 'District', price: 1250, seats: '800+ students', features: ['Everything in Growth', 'Multi-school admin', 'Dedicated support'] },
    ],
    invoices: [
      { id: 'INV-2026-07', date: '1 Jul 2026', amount: 960000, status: 'Paid' },
      { id: 'INV-2026-06', date: '1 Jun 2026', amount: 900000, status: 'Paid' },
      { id: 'INV-2026-05', date: '1 May 2026', amount: 855000, status: 'Paid' },
    ],
    classes: [
      { name: 'Primary 6 — English', seats: 42 },
      { name: 'Primary 5 — Mathematics', seats: 38 },
      { name: 'Primary 4 — All subjects', seats: 55 },
    ],
    usage: { activePct: 87, sessionsPerWeek: 4.2, topSubject: 'Mathematics', masteryLift: 23 },
  },
};
