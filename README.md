# ✅ **README.md (Version 1 — GitHub-Ready)**

# **Youth Telehealth Utilization, MEPS 2021–2023**

This repository contains Version 1 of the analytic workflow, figures, and regression models examining socioeconomic and insurance disparities in pediatric telehealth use during the post-pandemic period (2021–2023).

## **Overview**

Telehealth expanded rapidly during COVID-19, but it is unclear whether these gains persisted and whether all families benefited equally.
This analysis evaluates whether children’s telehealth use functioned as a *substitute* for in-person care or a *supplement*, and how these patterns vary by poverty level, insurance type, and health needs.

## **Data**

* MEPS Full-Year Consolidated Files (2021–2023)
* Linked Office-Based (OB) and Outpatient (OP) event files
* Person-year analytic dataset constructed for children ages **6–17**

## **Main Outcomes**

* **Any telehealth use** (binary)
* **Telehealth visits** (count)
* **In-person visits** (count)
* **Telehealth share** (bounded 0–1)

## **Models**

1. **Logistic regression** — probability of any telehealth use
2. **Negative binomial** — number of telehealth visits
3. **Negative binomial** — number of in-person visits
4. **Tobit model** — proportion of visits delivered via telehealth
5. **Interaction model** — SES × Year (poverty gap over time)

## **Key Findings (Version 1)**

* Higher-income children consistently have more telehealth use and higher telehealth share.
* Poor and uninsured children show the lowest probability of any telehealth use.
* Telehealth visit counts decline sharply over time for all groups, but the SES gradient persists.
* Supplementation patterns remain primarily among higher-income families.

## **Repository Structure**

```
/code/         # Stata do-files for data cleaning, merging, models
/output/       # Regression tables, prediction outputs
/figures/      # Model 1–4 plots, SES × Year interaction plot
/data/         # (Empty placeholder – data not uploaded)
README.md
```

## **Limitations (v1)**

* MEPS cannot fully distinguish behavioral vs non-behavioral telehealth visits.
* Zero-inflation remains substantial (~90% zero telehealth).
* Cross-sectional pooled design limits causal interpretation.

## **Next Steps**

* Add sensitivity checks (two-part model, ZINB, fractional logit).
* Add condition-specific analyses (mental health vs non-mental health).
* Add rural/urban, device access, broadband proxies (if available).
* Prepare Version 2 manuscript-ready tables and plots.

---

