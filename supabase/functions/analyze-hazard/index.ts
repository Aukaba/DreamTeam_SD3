// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This code runs on Supabase Edge Functions (Deno runtime).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "Server GEMINI_API_KEY secret is not set" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { imageBase64, mimeType } = await req.json();
    if (!imageBase64) {
      return new Response(
        JSON.stringify({ error: "Missing imageBase64 in request body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const prompt = `
You are a hazard detection AI for a community safety app.
Analyze this image and respond with ONLY a JSON object (no markdown, no code fences) using this exact format:
{
  "is_hazard": <true or false>,
  "detected_hazard": "<short descriptive name of what is seen>",
  "hazard_category": "<one of: Flood, Road damage, Accident, Fallen tree, Fire, Broken streetlight, Blocked road, Other>",
  "severity_level": "<one of: Low, Medium, High, Critical>",
  "confidence": <integer 0-100>
}

Rules:
- is_hazard: true ONLY if the image shows a real-world public safety or road hazard (e.g. flood, accident, fire, fallen tree, road damage, broken streetlight, blocked road). Set false for animals, people, food, selfies, nature scenery, objects, or anything unrelated to a public hazard.
- detected_hazard: concise phrase describing what is seen (e.g. "Flooded road", "Car accident", "Clear Roadway")
- hazard_category: pick the best match from the list above (only relevant when is_hazard is true)
- severity_level: Low = minor inconvenience, Medium = affects traffic/community, High = dangerous/urgent, Critical = life-threatening
- confidence: your confidence percentage as an integer
`;

    const gemini3Models = [
      "gemini-3.8-flash",
      "gemini-3-flash-preview",
      "gemini-3-flash",
      "gemini-3.6-flash",
      "gemini-3.8-pro",
    ];

    let candidateText = "{}";
    let lastError = null;

    for (const model of gemini3Models) {
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
      const geminiResponse = await fetch(geminiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: prompt },
                {
                  inline_data: {
                    mime_type: mimeType || "image/jpeg",
                    data: imageBase64,
                  },
                },
              ],
            },
          ],
        }),
      });

      if (geminiResponse.ok) {
        const data = await geminiResponse.json();
        candidateText =
          data.candidates?.[0]?.content?.parts?.[0]?.text || "{}";
        lastError = null;
        break;
      } else {
        lastError = await geminiResponse.text();
      }
    }

    if (lastError && candidateText === "{}") {
      return new Response(
        JSON.stringify({ error: `Gemini API error across all models: ${lastError}` }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(candidateText, {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

