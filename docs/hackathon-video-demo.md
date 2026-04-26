# Hackathon Video Demo Plan

## One-Line Pitch

TabAnywhere is Cursor Tab for every text box: completions, edits, and context-aware writing suggestions across desktop apps and mobile keyboards.

## Target Runtime

Aim for 2:30 to 3:00.

The video should feel fast, obvious, and concrete. Lead with the magic, then explain why it works.

## Story Arc

1. Hook: "What if Cursor Tab worked everywhere?"
2. Product demo: email, messages, docs, and context-aware writing.
3. Interaction model: ghost text for completions, diff popup for edits.
4. Technical explanation: rewrite-based edit prediction with Gemma 4.
5. Fine-tuning: LoRA SFT and DPO, explained in plain language.
6. Mobile finale: same prediction layer integrated into an iOS keyboard.

## Demo Script

### 0:00-0:15 - Hook

Visual: Start in an ordinary email compose field.

On-screen text:

```text
Cursor Tab, but anywhere.
```

Voiceover:

```text
Cursor Tab changed how developers write code. But most of our writing does not happen in code editors.

What if that same kind of intelligent, low-friction prediction worked everywhere?
```

Action:

Type:

```text
Hey Sarah, unfrotunately I can't make it tom
```

Show TabAnywhere suggesting:

```text
Hey Sarah, unfortunately I can't make it tomorrow.<|caret|>
```

Voiceover:

```text
Now it does.
```

### 0:15-0:35 - Email Completion

Visual: Email compose window.

User input:

```text
Thanks for sending this over. I'll take a look and get back to you
```

Suggestion as ghost text:

```text
by end of day.
```

Voiceover:

```text
In email, TabAnywhere can complete the obvious next phrase without taking over the message.
```

Acceptance:

Press the configured accept hotkey. The ghost text becomes real text.

### 0:35-0:55 - Messages Completion

Visual: Messages, Slack, or a chat-style field.

User input:

```text
running 5 min late, can you
```

Suggestion as ghost text:

```text
start without me?
```

Voiceover:

```text
In messages, it stays short and casual. The suggestion matches the context instead of sounding like an email assistant.
```

Acceptance:

Accept the suggestion.

### 0:55-1:15 - Edit Prediction

Visual: Document editor or rich text field.

Existing text:

```text
This feature make writing more faster.
```

Suggestion as diff popup:

```diff
- This feature make writing more faster.
+ This feature makes writing faster.
```

Voiceover:

```text
Traditional autocomplete only adds text after the cursor. But real writing also means fixing typos, tightening phrasing, and editing what came before.
```

Acceptance:

Accept the popup. Show the corrected sentence.

### 1:15-1:35 - Context From Screen

Visual: Support ticket, CRM, or customer message visible on screen. The visible context should explicitly include the fact used by the suggestion.

Visible context:

```text
Customer: Jamie Lee
Issue: Refund request
Status: Refund processed
```

User input:

```text
Hi Jamie, I checked your order and
```

Suggestion as ghost text:

```text
confirmed that the refund has been processed.
```

Voiceover:

```text
When useful, TabAnywhere can use visible screen context too. It only uses context that is actually present, so the suggestion is grounded in what the user can already see.
```

Note:

Do not use a context example where the model invents a date, reason, promise, personal detail, or unsupported fact.

### 1:35-1:55 - Unified Prediction Model

Visual: Show a simple diagram.

```text
Editable text window + caret
        |
        v
Gemma 4 edit prediction model
        |
        v
Rewritten text window
        |
        v
Local diff engine
        |
        v
Ghost text or red/green edit popup
```

Voiceover:

```text
The key idea is that completions and edits are the same problem underneath.

We ask the model to rewrite a small window of text around the cursor. If the rewrite only inserts text at the cursor, we show ghost text. If it changes existing text, we show a red and green diff popup.
```

### 1:55-2:25 - Fine-Tuning Explanation

Visual: Before and after fine-tuning comparison.

Before fine-tuning:

```text
Input:
I can't make it today bec<|caret|>

Bad output:
I can't make it today because my car broke down and I have a doctor's appointment.<|caret|>
```

After fine-tuning:

```text
Input:
I can't make it today bec<|caret|>

Better output:
I can't make it today because<|caret|>
```

Voiceover:

```text
We started from Gemma 4, then adapted it for this exact interaction using LoRA fine-tuning.

First, supervised fine-tuning teaches examples of good behavior: complete the obvious phrase, fix the local typo, preserve the user's tone, and return no change when no suggestion is useful.

Then preference tuning teaches restraint. It learns to prefer the helpful suggestion over the annoying one, and the grounded suggestion over the invented one.
```

On-screen labels:

```text
SFT: learn from examples
DPO: learn which answer is better
LoRA: adapt the model efficiently
```

### 2:25-2:50 - iOS Keyboard

Visual: iOS app or keyboard integration.

Demo sequence:

1. Open Messages, Mail, or Notes.
2. Type a partial sentence.
3. Show a keyboard-level suggestion.
4. Accept it.
5. Show an edit suggestion if available.

Voiceover:

```text
Because the interface can live in a keyboard, the same prediction layer can follow you onto iOS.

Messages, Mail, Notes, forms: one model, one interaction pattern, everywhere you type.
```

### 2:50-3:00 - Close

Visual: Montage of email, messages, docs, and iOS keyboard.

On-screen text:

```text
TabAnywhere
Edit prediction for every text box.
```

Voiceover:

```text
Cursor Tab showed us what writing with prediction can feel like. TabAnywhere brings that feeling to the rest of computing.
```

## Example Library

Use these examples as backup shots if one app is flaky during recording.

### Completion Examples

Email:

```text
Input:
Thanks for sending this over. I'll take a look and get back to you<|caret|>

Suggestion:
Thanks for sending this over. I'll take a look and get back to you by end of day.<|caret|>
```

Message:

```text
Input:
running 5 min late, can you<|caret|>

Suggestion:
running 5 min late, can you start without me?<|caret|>
```

Docs:

```text
Input:
The main benefit is that users can keep writing without<|caret|>

Suggestion:
The main benefit is that users can keep writing without breaking their flow.<|caret|>
```

Longer obvious completion:

```text
Input:
The three goals for this launch are:
1. Reduce friction in common writing workflows
2. Keep the user in control of every suggestion
3.<|caret|>

Suggestion:
The three goals for this launch are:
1. Reduce friction in common writing workflows
2. Keep the user in control of every suggestion
3. Make the experience work consistently across apps<|caret|>
```

### Edit Examples

Typo correction:

```text
Input:
Hi Sam, thanks for meetign with me yesterday.<|caret|>

Suggestion:
Hi Sam, thanks for meeting with me yesterday.<|caret|>
```

Grammar correction:

```text
Input:
This feature make writing more faster.<|caret|>

Suggestion:
This feature makes writing faster.<|caret|>
```

Punctuation:

```text
Input:
Sounds good I'll send it over this afternoon<|caret|>

Suggestion:
Sounds good. I'll send it over this afternoon.<|caret|>
```

Restraint:

```text
Input:
I can't make it today because<|caret|>

Suggestion:
I can't make it today because<|caret|>
```

The restraint example is important. It shows that the model should not invent a reason for the user.

### Context-Aware Examples

Support reply:

```text
Visible context:
Customer: Jamie Lee
Issue: Refund request
Status: Refund processed

Input:
Hi Jamie, I checked your order and<|caret|>

Suggestion:
Hi Jamie, I checked your order and confirmed that the refund has been processed.<|caret|>
```

Calendar reply:

```text
Visible context:
Meeting: Design review
Time: 2:00 PM

Input:
That works for me. I'll see you at<|caret|>

Suggestion:
That works for me. I'll see you at 2:00 PM.<|caret|>
```

Use this only if the meeting time is visible in the shot.

## Recording Checklist

- Keep examples short enough that the viewer understands each one in under five seconds.
- Show the acceptance gesture at least twice.
- Use ghost text for insertions at the cursor.
- Use a red/green diff popup for edits to existing text.
- Avoid examples that invent personal details, excuses, dates, links, or commitments.
- Include one no-op or restraint example if there is time.
- Show architecture only after the viewer has already seen the product work.
- End on the iOS keyboard, because it makes "anywhere" feel literal.

## Backup 60-Second Cut

Voiceover:

```text
What if Cursor Tab worked everywhere?

TabAnywhere brings edit prediction to ordinary text fields: email, messages, docs, forms, and mobile keyboards.

Completions appear as ghost text. Edits appear as a red and green diff, so you can see exactly what will change before accepting.

Under the hood, we use a Gemma 4-based model. Instead of asking it for fragile patch commands, we ask it to rewrite a small window around the cursor, then our client computes the diff.

We fine-tuned the model with LoRA. Supervised examples teach useful completions, typo fixes, and no-op cases. Preference tuning teaches restraint, so the model avoids overconfident or invented suggestions.

The result is Cursor Tab for the rest of computing: fast, local-first edit prediction anywhere you type.
```

## Alternative Humorous Script

This version keeps the same product beats, but makes the narration lighter and more memorable. Use it if the hackathon audience is friendly and you want the demo to feel more alive than corporate.

### 0:00-0:15 - Hook

Visual: Open an email compose window. Pause for a beat before typing.

Voiceover:

```text
Developers have Cursor Tab, which is basically autocomplete with a suspiciously good sense of timing.

But the rest of us are still out here manually typing emails like it is 2014.

So we built TabAnywhere: Cursor Tab, but for every text box.
```

Action:

Type:

```text
Hey Sarah, unfrotunately I can't make it tom
```

Show suggestion:

```text
Hey Sarah, unfortunately I can't make it tomorrow.<|caret|>
```

Voiceover:

```text
It fixes the typo, finishes the thought, and does not judge me for spelling unfortunately like a keyboard incident.
```

### 0:15-0:35 - Email

Visual: Email compose window.

User input:

```text
Thanks for sending this over. I'll take a look and get back to you
```

Ghost text:

```text
by end of day.
```

Voiceover:

```text
In email, it completes the sentence you were probably going to write anyway.

Tiny productivity win. Zero inspirational quote required.
```

### 0:35-0:55 - Messages

Visual: Messages, Slack, or chat.

User input:

```text
running 5 min late, can you
```

Ghost text:

```text
start without me?
```

Voiceover:

```text
In chat, it keeps things short, because nobody wants a three-paragraph Slack message that starts with "I hope this finds you well."
```

### 0:55-1:15 - Edits

Visual: Document editor.

Existing text:

```text
This feature make writing more faster.
```

Diff popup:

```diff
- This feature make writing more faster.
+ This feature makes writing faster.
```

Voiceover:

```text
And unlike normal autocomplete, TabAnywhere can edit text that already exists.

Because writing is not just adding words at the end. Sometimes writing is looking at a sentence and quietly admitting it needs help.
```

### 1:15-1:35 - Screen Context

Visual: Support ticket or CRM with visible facts.

Visible context:

```text
Customer: Jamie Lee
Issue: Refund request
Status: Refund processed
```

User input:

```text
Hi Jamie, I checked your order and
```

Ghost text:

```text
confirmed that the refund has been processed.
```

Voiceover:

```text
It can also use context from what is visible on your screen.

Not mysterious mind-reading context. Just the useful stuff already sitting there, waiting for someone to copy it into a sentence.
```

### 1:35-1:55 - How It Works

Visual: Architecture diagram.

```text
Text window + caret
        |
        v
Gemma 4 model
        |
        v
Rewritten text window
        |
        v
Local diff engine
        |
        v
Ghost text or edit popup
```

Voiceover:

```text
The trick is that completions and edits are secretly the same shape.

We give the model a small window of text with a caret marker, and it predicts the next version of that window.

If the only change is new text after the cursor, we show ghost text. If it changes existing text, we show a diff, because surprise edits are how software loses friends.
```

### 1:55-2:25 - Fine-Tuning

Visual: Before and after fine-tuning.

Before:

```text
Input:
I can't make it today bec<|caret|>

Bad output:
I can't make it today because my car broke down and I have a doctor's appointment.<|caret|>
```

After:

```text
Input:
I can't make it today bec<|caret|>

Better output:
I can't make it today because<|caret|>
```

Voiceover:

```text
We started with Gemma 4 and fine-tuned it with LoRA, which is a lightweight way to teach a model a new job without retraining the whole thing from scratch.

First, SFT shows it examples of good predictions: finish obvious phrases, fix local mistakes, preserve tone, and sometimes do absolutely nothing.

Then DPO teaches taste. It learns that "because my car exploded" is a bold creative choice, but not a good autocomplete suggestion.
```

### 2:25-2:50 - iOS Keyboard

Visual: iOS keyboard demo.

Voiceover:

```text
And because this can live in a keyboard, TabAnywhere can follow you onto iOS.

Same idea, smaller screen: messages, mail, notes, forms, all getting the same edit prediction layer.
```

### 2:50-3:00 - Close

Visual: Fast montage of desktop and iOS examples.

On-screen text:

```text
TabAnywhere
Cursor Tab for every text box.
```

Voiceover:

```text
TabAnywhere is for all the writing that happens outside the code editor.

Less typing, fewer tiny mistakes, and just enough intelligence to stay helpful without becoming the main character.
```
