# Writing to WAEC (audit G4)

WAEC owns the copyright in its papers. Paragon publishes 4,206 past objective questions as public pages, and serves them in the app. The questions were collected from a public archive (myschool.ng). Many sites do the same, but that is not permission.

This page is a starting point for the owner. It is **not legal advice**: have someone who knows Nigerian copyright law read it before relying on any of it.

## Why write
- **To ask permission** for what Paragon already does, so the past-question pages rest on agreement rather than on the fact that others do it.
- **A partnership opening.** WAEC runs its own e-learning services. A free, ad-free study tool that labels past and practice questions apart, and corrects answers as students report them, may be useful to them.

## Before sending
- Check the archive's terms of use for its question text. They may grant nothing.
- Decide what Paragon will do if WAEC says no: take down the static pages, keep the questions in the app, or both. Know the answer before asking the question.
- Send it from a domain address once there is one (audit G2), not a personal Gmail.

## Draft

> **To:** The Head of National Office, The West African Examinations Council, Lagos
>
> **Subject:** Permission to publish past WASSCE objective questions in a free study tool
>
> Dear Sir/Madam,
>
> I run Paragon (`https://paragon-hq.web.app`), a free WAEC preparation tool for secondary school students. It carries no adverts and is built by a small team in Nigeria. Students use it to learn topic by topic, practise, and sit past objective papers under exam conditions.
>
> Paragon presents about 4,200 past WASSCE objective questions in Mathematics, Further Mathematics and Physics, each with its answer and, where we have one, a worked solution.
> - Each question is labelled with its paper and year.
> - Each sits apart from our own practice questions, which are labelled "Paragon practice".
> - The site states that Paragon is not affiliated with or endorsed by WAEC.
> - Students can report any answer they believe is wrong, and we correct it.
>
> We would like to do this with the Council's permission. Specifically, we ask whether WAEC would grant a licence, or set conditions, for us to:
> 1. show past objective questions, with their answers, to students free of charge;
> 2. publish them as individual web pages, so students searching for a question can find it.
>
> We are glad to follow any attribution wording the Council prefers. If there are papers or years the Council would rather we did not publish, we will remove them. We would also welcome a conversation about working together, for instance on official answer keys or examiner commentary.
>
> Yours faithfully,
>
> [Name]
> [Role], Paragon
> [Contact address]

## After a reply
- Record the decision and its date in `docs/LAUNCH_CHECKLIST.md`.
- If there are attribution terms, they go in `tools/site/render.js`'s footer and in `about_content.dart`, so the app and the static pages say the same thing.
