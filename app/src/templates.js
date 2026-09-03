// All templates are procedural (gradients + geometric motifs drawn on
// <canvas>), not copied images — keeps this clean of Crafto's actual assets.

export const CATEGORIES = [
  {
    id: "morning",
    label: "Good Morning",
    quotes: [
      "Rise with the sun, shine like it too.",
      "A fresh page. Write something good on it today.",
      "Morning light, quiet mind, steady heart.",
    ],
    templates: [
      { id: "m1", from: "#F2C14E", to: "#E8A23D", motif: "rays" },
      { id: "m2", from: "#EFE6D3", to: "#E8A23D", motif: "waves" },
      { id: "m3", from: "#7A2438", to: "#F2C14E", motif: "rays" },
    ],
  },
  {
    id: "motivation",
    label: "Motivational",
    quotes: [
      "Small steps, repeated daily, outrun big leaps taken rarely.",
      "Discipline is choosing what you want most over what you want now.",
      "Start before you're ready. Ready rarely comes first.",
    ],
    templates: [
      { id: "mo1", from: "#1B2A4A", to: "#7A2438", motif: "grid" },
      { id: "mo2", from: "#101A30", to: "#1B2A4A", motif: "diagonal" },
      { id: "mo3", from: "#7A2438", to: "#1B2A4A", motif: "waves" },
    ],
  },
  {
    id: "festival",
    label: "Festival",
    quotes: [
      "Warm lights, warmer company. Happy festivities.",
      "May this season bring color to every corner of your life.",
      "Celebrate loudly, love deeply, laugh often.",
    ],
    templates: [
      { id: "f1", from: "#7A2438", to: "#E8A23D", motif: "diamond" },
      { id: "f2", from: "#E8A23D", to: "#F2C14E", motif: "diamond" },
      { id: "f3", from: "#1B2A4A", to: "#E8A23D", motif: "waves" },
    ],
  },
  {
    id: "business",
    label: "Business",
    quotes: [
      "Consistency compounds. Show up again tomorrow.",
      "Good work, done quietly, speaks the loudest.",
      "Build the thing you'd want to buy.",
    ],
    templates: [
      { id: "b1", from: "#101A30", to: "#1B2A4A", motif: "grid" },
      { id: "b2", from: "#1B2A4A", to: "#4A4339", motif: "diagonal" },
      { id: "b3", from: "#EFE6D3", to: "#1B2A4A", motif: "grid" },
    ],
  },
];
