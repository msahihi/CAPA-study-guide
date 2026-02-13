# CAPA Certification Mock Exams

This directory contains two comprehensive mock exams designed to help you prepare for the Certified Argo Project Associate (CAPA) certification.

## Exam Overview

### Format

- **Total Questions:** 60 questions per exam
- **Time Limit:** 90 minutes
- **Passing Score:** 70% (42 correct answers)
- **Question Types:** Multiple choice (4 options: A, B, C, D)

### Domain Distribution

Questions are distributed according to the official CAPA exam weights:

| Domain | Weight | Questions per Exam |
|--------|--------|-------------------|
| Argo Workflows | 36% | 22 questions (Q1-22) |
| Argo CD | 34% | 20 questions (Q23-42) |
| Argo Rollouts | 18% | 11 questions (Q43-53) |
| Argo Events | 12% | 7 questions (Q54-60) |

## Mock Exam Files

1. **mock-exam-set-1.md** - First complete practice exam
2. **mock-exam-set-2.md** - Second complete practice exam

Each exam contains 60 unique questions covering all CAPA domains.

## How to Use These Mock Exams

### Recommended Study Approach

1. **Initial Assessment (Week 1-2)**
   - Take Mock Exam Set 1 under timed conditions (90 minutes)
   - Don't look at answers until complete
   - Score yourself and identify weak areas
   - Review all explanations, especially for incorrect answers

2. **Focused Study (Weeks 3-5)**
   - Study the main CAPA guide focusing on weak domains
   - Practice with kubectl, argocd CLI, and argo CLI
   - Complete hands-on labs for areas where you scored poorly
   - Review official Argo Project documentation
   - Practice YAML configurations and CLI commands

3. **Final Assessment (Week 6)**
   - Take Mock Exam Set 2 under timed conditions
   - Compare scores with Set 1 to measure improvement
   - Review both exams and their explanations
   - Deep dive into any remaining knowledge gaps
   - Create flashcards for unclear concepts
   - Practice until consistently scoring 75%+

### Exam-Taking Tips

#### Before the Exam

- Set up a quiet environment with no distractions
- Have paper and pen ready for notes
- Set a timer for 90 minutes
- Use a separate browser tab or print the exam
- Don't look ahead at answers

#### During the Exam

- **Time Management:** You have 1.5 minutes per question on average
  - First pass: Answer questions you know confidently (45-60 minutes)
  - Second pass: Work through harder questions (20-30 minutes)
  - Final pass: Review flagged questions (10-15 minutes)
- Mark questions you're unsure about and return to them
- Read each question carefully - look for keywords like "NOT", "BEST", "MUST"
- Eliminate obviously wrong answers first
- For YAML/configuration questions, check syntax carefully
- For CLI questions, verify command structure and flags

#### After the Exam

1. Score yourself using the answer key
2. Calculate your percentage (correct answers / 60 × 100)
3. Review ALL explanations, not just wrong answers
4. Note patterns in mistakes (specific domains, question types)
5. Create a study plan for weak areas

## Scoring Guide

### Understanding Your Score

| Score Range | Level | Recommendation |
|------------|-------|----------------|
| 90-100% (54-60) | Excellent | You're ready! Review minor gaps and take the exam |
| 80-89% (48-53) | Very Good | Review weak areas, focus on speed and accuracy |
| 70-79% (42-47) | Good | Passing score, but study more for confidence |
| 60-69% (36-41) | Fair | Significant study needed, identify weak domains |
| Below 60% (<36) | Needs Work | Comprehensive study required, focus on fundamentals |

### Score Analysis by Domain

After completing each mock exam, calculate your score per domain:

**Argo Workflows (Questions 1-22):**

- Score: _____ / 22 = _____%
- Target: At least 15/22 (68%)

**Argo CD (Questions 23-42):**

- Score: _____ / 20 = _____%
- Target: At least 14/20 (70%)

**Argo Rollouts (Questions 43-53):**

- Score: _____ / 11 = _____%
- Target: At least 8/11 (73%)

**Argo Events (Questions 54-60):**

- Score: _____ / 7 = _____%
- Target: At least 5/7 (71%)

If any domain is below target, prioritize studying that area.

## Question Types You'll Encounter

### 1. Conceptual Understanding (30-35%)

- Core concepts and architecture
- Component relationships
- Workflow patterns and best practices
- Example: "What is the purpose of Argo CD's Application Controller?"

### 2. Practical Scenarios (25-30%)

- Real-world problem solving
- Choosing appropriate solutions
- Troubleshooting approaches
- Example: "An application deployment is stuck in Progressing state. What should you check first?"

### 3. YAML Configuration (20-25%)

- Syntax and structure
- Required vs optional fields
- Configuration best practices
- Example: "Which field is required in an Argo Rollouts BlueGreen strategy?"

### 4. CLI Commands (15-20%)

- Command syntax and flags
- Common operations
- Output interpretation
- Example: "Which command promotes a Rollout to the active service?"

### 5. Troubleshooting (10-15%)

- Error diagnosis
- Log analysis
- Common issues and solutions
- Example: "A Workflow fails with 'ImagePullBackOff'. What's the most likely cause?"

## Exam Strategies

### Time Management Strategy

**Recommended approach for 90 minutes:**

1. **Quick Win Pass (30-40 minutes)**
   - Answer all questions you know immediately
   - Skip complex scenarios or long YAML questions
   - Build confidence and bank time

2. **Deep Work Pass (30-40 minutes)**
   - Tackle skipped questions
   - Read scenarios carefully
   - Analyze YAML configurations
   - Use elimination method

3. **Review Pass (10-20 minutes)**
   - Double-check marked questions
   - Verify you answered all questions
   - Don't second-guess confident answers
   - Make educated guesses on any remaining unknowns

### Multiple Choice Strategies

**Elimination Method:**

1. Cross out clearly wrong answers
2. Compare remaining options
3. Look for subtle differences
4. Choose the most complete/accurate answer

**Keyword Detection:**

- "ALWAYS" or "NEVER" - Often incorrect (too absolute)
- "BEST" or "MOST" - Look for optimal solution
- "NOT" or "EXCEPT" - Invert your thinking
- "MUST" or "REQUIRED" - Focus on mandatory elements

**YAML Questions:**

- Check indentation (YAML is whitespace-sensitive)
- Verify field names (case-sensitive)
- Look for required fields
- Check for syntax errors (colons, hyphens, quotes)

**CLI Questions:**

- Verify command structure: `command subcommand resource flags`
- Check flag syntax (single dash `-` vs double dash `--`)
- Look for deprecated flags or commands
- Consider command output and what it reveals

## Common Pitfalls to Avoid

### During Preparation

- Don't just memorize answers - understand WHY
- Don't skip hands-on practice
- Don't ignore domains you find difficult
- Don't cram - consistent study is better

### During Exam

- Don't spend too long on one question (max 3 minutes)
- Don't change answers unless you find a clear error
- Don't leave questions blank - always guess if unsure
- Don't panic if you see unfamiliar topics

## Additional Resources

### Official Documentation

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Argo Workflows Documentation](https://argoproj.github.io/argo-workflows/)
- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [Argo Events Documentation](https://argoproj.github.io/argo-events/)

### Hands-On Practice

- Set up a local Kubernetes cluster (minikube, kind, k3s)
- Install all Argo Project components
- Work through official examples and tutorials
- Create your own test applications and workflows

### Study Materials

- Review the main CAPA study guide in this repository
- Watch Argo Project community meetings and demos
- Read Argo Project blog posts and case studies
- Join the CNCF Slack #argo-cd, #argo-workflows channels

## Score Tracking

Use this table to track your progress across both mock exams:

| Mock Exam | Date Taken | Score | Pass? | Workflows | Argo CD | Rollouts | Events | Time Used |
|-----------|-----------|-------|-------|-----------|---------|----------|--------|-----------|
| Set 1 | _____ | ___/60 | ___% | ___/22 | ___/20 | ___/11 | ___/7 | ___ min |
| Set 2 | _____ | ___/60 | ___% | ___/22 | ___/20 | ___/11 | ___/7 | ___ min |

**Target:** Score 75%+ (45/60) on Set 2 with time to spare

**Note:** You can retake each exam after additional study to track improvement.

## Ready to Start?

1. Choose a mock exam (start with Set 1)
2. Set up your test environment
3. Set timer for 90 minutes
4. Open the exam file
5. Begin answering questions
6. Don't peek at answers until done!
