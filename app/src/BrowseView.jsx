import React, { useState, useEffect, useRef, useCallback } from "react";
import { renderPoster } from "./canvasRenderer.js";
import "./BrowseView.css";

export default function BrowseView({ categories }) {
  const [categoryId, setCategoryId] = useState(categories[0].id);
  const category = categories.find((c) => c.id === categoryId);
  const [quotes, setQuotes] = useState(category.quotes);
  const [loading, setLoading] = useState(false);
  const [copiedIndex, setCopiedIndex] = useState(null);
  const hiddenCanvasRef = useRef(null);

  const fetchQuotes = useCallback(async (cat) => {
    setLoading(true);
    try {
      const base = import.meta.env.VITE_API_BASE_URL || "";
      const res = await fetch(`${base}/api/v1/quotes`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ topic: cat.label, count: 8 }),
      });
      const data = await res.json();
      if (Array.isArray(data.quotes) && data.quotes.length) {
        setQuotes(data.quotes);
      } else {
        setQuotes(cat.quotes);
      }
    } catch (err) {
      console.error("quotes fetch failed:", err);
      setQuotes(cat.quotes);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchQuotes(category);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [categoryId]);

  function handleCopy(text, idx) {
    navigator.clipboard.writeText(text).then(() => {
      setCopiedIndex(idx);
      setTimeout(() => setCopiedIndex(null), 1500);
    });
  }

  function handleDownload(text, idx) {
    const canvas = hiddenCanvasRef.current;
    const t = category.templates[idx % category.templates.length];
    renderPoster(canvas, { template: t, name: "", quote: text, photoImg: null });
    const link = document.createElement("a");
    link.download = `vaultai-${category.id}-${idx + 1}.png`;
    link.href = canvas.toDataURL("image/png");
    link.click();
  }

  async function handleShare(text) {
    if (navigator.share) {
      try {
        await navigator.share({ text, title: "VaultAI" });
      } catch (err) {
        // user cancelled — no-op
      }
    } else {
      navigator.clipboard.writeText(text);
      alert("Copied — share it anywhere you like.");
    }
  }

  return (
    <div className="browse">
      <nav className="browse-tabs">
        {categories.map((c) => (
          <button
            key={c.id}
            className={`browse-tab ${c.id === categoryId ? "active" : ""}`}
            onClick={() => setCategoryId(c.id)}
          >
            {c.label}
          </button>
        ))}
      </nav>

      <h1 className="browse-title">{category.label}</h1>

      {loading ? (
        <div className="browse-loading">Generating fresh ones…</div>
      ) : (
        <div className="browse-grid">
          {quotes.map((q, idx) => {
            const t = category.templates[idx % category.templates.length];
            return (
              <article
                key={idx}
                className="quote-card"
                style={{ background: `linear-gradient(135deg, ${t.from}, ${t.to})` }}
              >
                <p className="quote-text">{q}</p>
                <div className="quote-actions">
                  <button onClick={() => handleCopy(q, idx)}>
                    {copiedIndex === idx ? "Copied" : "Copy"}
                  </button>
                  <button onClick={() => handleDownload(q, idx)}>Download</button>
                  <button onClick={() => handleShare(q)}>Share</button>
                </div>
              </article>
            );
          })}
        </div>
      )}

      <canvas ref={hiddenCanvasRef} className="hidden-canvas" />
    </div>
  );
}
