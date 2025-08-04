import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/crdt_types.dart';
import '../../../core/crdt/lww_register.dart';
import '../../../core/crdt/or_set.dart';
import '../../../core/database/crdt_models.dart';

/// Performance review status
enum PerformanceStatus {
  draft, // Draft review
  submitted, // Submitted for approval
  approved, // Approved by manager
  completed, // Review completed
  archived // Archived review
}

/// Performance rating scale
enum PerformanceRating {
  outstanding, // 5 - Outstanding
  exceeds, // 4 - Exceeds expectations
  meets, // 3 - Meets expectations
  developing, // 2 - Developing
  unsatisfactory // 1 - Unsatisfactory
}

/// Goal status
enum GoalStatus {
  notStarted, // Not started
  inProgress, // In progress
  completed, // Completed
  overdue, // Overdue
  cancelled // Cancelled
}

/// CRDT-enabled Performance Record model
class CRDTPerformanceRecord implements CRDTModel {
  @override
  final String id;

  @override
  final String nodeId;

  @override
  final HLCTimestamp createdAt;

  @override
  HLCTimestamp updatedAt;

  @override
  CRDTVectorClock version;

  @override
  bool isDeleted;

  // Basic information
  late LWWRegister<String> employeeId;
  late LWWRegister<String> reviewerId;
  late LWWRegister<String> reviewPeriod; // Q1_2024, H1_2024, Annual_2024
  late LWWRegister<DateTime> reviewStartDate;
  late LWWRegister<DateTime> reviewEndDate;
  late LWWRegister<DateTime?> reviewDueDate;
  late LWWRegister<String>
      status; // draft, submitted, approved, completed, archived
  late LWWRegister<String>
      reviewType; // quarterly, semi_annual, annual, probation

  // Overall rating
  late LWWRegister<String?>
      overallRating; // outstanding, exceeds, meets, developing, unsatisfactory
  late LWWRegister<double?> overallScore; // 1.0 to 5.0
  late LWWRegister<String?> overallComments;

  // Performance categories with ratings
  late LWWRegister<String?> jobKnowledgeRating;
  late LWWRegister<double?> jobKnowledgeScore;
  late LWWRegister<String?> jobKnowledgeComments;

  late LWWRegister<String?> qualityOfWorkRating;
  late LWWRegister<double?> qualityOfWorkScore;
  late LWWRegister<String?> qualityOfWorkComments;

  late LWWRegister<String?> productivityRating;
  late LWWRegister<double?> productivityScore;
  late LWWRegister<String?> productivityComments;

  late LWWRegister<String?> communicationRating;
  late LWWRegister<double?> communicationScore;
  late LWWRegister<String?> communicationComments;

  late LWWRegister<String?> teamworkRating;
  late LWWRegister<double?> teamworkScore;
  late LWWRegister<String?> teamworkComments;

  late LWWRegister<String?> leadershipRating;
  late LWWRegister<double?> leadershipScore;
  late LWWRegister<String?> leadershipComments;

  late LWWRegister<String?> initiativeRating;
  late LWWRegister<double?> initiativeScore;
  late LWWRegister<String?> initiativeComments;

  // Strengths and areas for improvement
  late LWWRegister<String?> strengths;
  late LWWRegister<String?> areasForImprovement;
  late LWWRegister<String?> developmentPlan;
  late LWWRegister<String?> careerAspirations;

  // Goals and objectives as OR-Set
  late ORSet<String> goalIds;

  // Training and development
  late LWWRegister<String?> trainingNeeds;
  late LWWRegister<String?> skillGaps;
  late LWWRegister<String?> mentorshipNeeds;

  // Employee self-assessment
  late LWWRegister<String?> selfAssessment;
  late LWWRegister<String?> selfRating;
  late LWWRegister<double?> selfScore;
  late LWWRegister<String?> employeeComments;

  // Manager assessment
  late LWWRegister<String?> managerAssessment;
  late LWWRegister<String?> managerRecommendations;
  late LWWRegister<DateTime?> managerSignOffDate;

  // HR review
  late LWWRegister<String?> hrComments;
  late LWWRegister<DateTime?> hrReviewDate;
  late LWWRegister<String?> hrRecommendations;

  // Action items and follow-ups
  late LWWRegister<String?> actionItems;
  late LWWRegister<DateTime?> nextReviewDate;
  late LWWRegister<String?> followUpRequired;

  // Salary and promotion recommendations
  late LWWRegister<bool> salaryIncreaseRecommended;
  late LWWRegister<double?> recommendedSalaryIncrease;
  late LWWRegister<bool> promotionRecommended;
  late LWWRegister<String?> recommendedPosition;
  late LWWRegister<DateTime?> recommendedEffectiveDate;

  // Additional information
  late LWWRegister<Map<String, dynamic>?> metadata;

  CRDTPerformanceRecord({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String empId,
    required String reviewerId,
    required String period,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? dueDate,
    String reviewStatus = 'draft',
    String type = 'annual',
    String? overallRat,
    double? overallSc,
    String? overallComm,
    String? jobKnowledge,
    double? jobKnowledgeSc,
    String? jobKnowledgeComm,
    String? qualityWork,
    double? qualityWorkSc,
    String? qualityWorkComm,
    String? productivity,
    double? productivitySc,
    String? productivityComm,
    String? communication,
    double? communicationSc,
    String? communicationComm,
    String? teamwork,
    double? teamworkSc,
    String? teamworkComm,
    String? leadership,
    double? leadershipSc,
    String? leadershipComm,
    String? initiative,
    double? initiativeSc,
    String? initiativeComm,
    String? empStrengths,
    String? improvements,
    String? devPlan,
    String? career,
    String? training,
    String? skills,
    String? mentorship,
    String? selfAssess,
    String? selfRat,
    double? selfSc,
    String? empComments,
    String? managerAssess,
    String? managerRec,
    DateTime? managerSignOff,
    String? hrComm,
    DateTime? hrReview,
    String? hrRec,
    String? actions,
    DateTime? nextReview,
    String? followUp,
    bool salaryIncrease = false,
    double? salaryAmount,
    bool promotion = false,
    String? newPosition,
    DateTime? effectiveDate,
    Map<String, dynamic>? performanceMetadata,
    this.isDeleted = false,
  }) {
    // Initialize basic information
    employeeId = LWWRegister(empId, createdAt);
    this.reviewerId = LWWRegister(reviewerId, createdAt);
    reviewPeriod = LWWRegister(period, createdAt);
    reviewStartDate = LWWRegister(startDate, createdAt);
    reviewEndDate = LWWRegister(endDate, createdAt);
    reviewDueDate = LWWRegister(dueDate, createdAt);
    status = LWWRegister(reviewStatus, createdAt);
    reviewType = LWWRegister(type, createdAt);

    // Initialize overall rating
    overallRating = LWWRegister(overallRat, createdAt);
    overallScore = LWWRegister(overallSc, createdAt);
    overallComments = LWWRegister(overallComm, createdAt);

    // Initialize performance categories
    jobKnowledgeRating = LWWRegister(jobKnowledge, createdAt);
    jobKnowledgeScore = LWWRegister(jobKnowledgeSc, createdAt);
    jobKnowledgeComments = LWWRegister(jobKnowledgeComm, createdAt);

    qualityOfWorkRating = LWWRegister(qualityWork, createdAt);
    qualityOfWorkScore = LWWRegister(qualityWorkSc, createdAt);
    qualityOfWorkComments = LWWRegister(qualityWorkComm, createdAt);

    productivityRating = LWWRegister(productivity, createdAt);
    productivityScore = LWWRegister(productivitySc, createdAt);
    productivityComments = LWWRegister(productivityComm, createdAt);

    communicationRating = LWWRegister(communication, createdAt);
    communicationScore = LWWRegister(communicationSc, createdAt);
    communicationComments = LWWRegister(communicationComm, createdAt);

    teamworkRating = LWWRegister(teamwork, createdAt);
    teamworkScore = LWWRegister(teamworkSc, createdAt);
    teamworkComments = LWWRegister(teamworkComm, createdAt);

    leadershipRating = LWWRegister(leadership, createdAt);
    leadershipScore = LWWRegister(leadershipSc, createdAt);
    leadershipComments = LWWRegister(leadershipComm, createdAt);

    initiativeRating = LWWRegister(initiative, createdAt);
    initiativeScore = LWWRegister(initiativeSc, createdAt);
    initiativeComments = LWWRegister(initiativeComm, createdAt);

    // Initialize development areas
    strengths = LWWRegister(empStrengths, createdAt);
    areasForImprovement = LWWRegister(improvements, createdAt);
    developmentPlan = LWWRegister(devPlan, createdAt);
    careerAspirations = LWWRegister(career, createdAt);

    // Initialize goals
    goalIds = ORSet(nodeId);

    // Initialize training and development
    trainingNeeds = LWWRegister(training, createdAt);
    skillGaps = LWWRegister(skills, createdAt);
    mentorshipNeeds = LWWRegister(mentorship, createdAt);

    // Initialize employee self-assessment
    selfAssessment = LWWRegister(selfAssess, createdAt);
    selfRating = LWWRegister(selfRat, createdAt);
    selfScore = LWWRegister(selfSc, createdAt);
    employeeComments = LWWRegister(empComments, createdAt);

    // Initialize manager assessment
    managerAssessment = LWWRegister(managerAssess, createdAt);
    managerRecommendations = LWWRegister(managerRec, createdAt);
    managerSignOffDate = LWWRegister(managerSignOff, createdAt);

    // Initialize HR review
    hrComments = LWWRegister(hrComm, createdAt);
    hrReviewDate = LWWRegister(hrReview, createdAt);
    hrRecommendations = LWWRegister(hrRec, createdAt);

    // Initialize action items
    actionItems = LWWRegister(actions, createdAt);
    nextReviewDate = LWWRegister(nextReview, createdAt);
    followUpRequired = LWWRegister(followUp, createdAt);

    // Initialize salary and promotion recommendations
    salaryIncreaseRecommended = LWWRegister(salaryIncrease, createdAt);
    recommendedSalaryIncrease = LWWRegister(salaryAmount, createdAt);
    promotionRecommended = LWWRegister(promotion, createdAt);
    recommendedPosition = LWWRegister(newPosition, createdAt);
    recommendedEffectiveDate = LWWRegister(effectiveDate, createdAt);

    // Initialize additional information
    metadata = LWWRegister(performanceMetadata, createdAt);
  }

  /// Calculate average performance score
  double get averageScore {
    final scores = [
      jobKnowledgeScore.value,
      qualityOfWorkScore.value,
      productivityScore.value,
      communicationScore.value,
      teamworkScore.value,
      leadershipScore.value,
      initiativeScore.value,
    ].where((score) => score != null).cast<double>();

    if (scores.isEmpty) return 0.0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// Check if review is overdue
  bool get isOverdue {
    final due = reviewDueDate.value;
    if (due == null) return false;
    return DateTime.now().isAfter(due) && status.value != 'completed';
  }

  /// Check if review is completed
  bool get isCompleted => status.value == 'completed';

  /// Update overall rating
  void updateOverallRating({
    String? rating,
    double? score,
    String? comments,
    required HLCTimestamp timestamp,
  }) {
    if (rating != null) overallRating.setValue(rating, timestamp);
    if (score != null) overallScore.setValue(score, timestamp);
    if (comments != null) overallComments.setValue(comments, timestamp);
    _updateTimestamp(timestamp);
  }

  /// Update performance category
  void updatePerformanceCategory({
    required String category,
    String? rating,
    double? score,
    String? comments,
    required HLCTimestamp timestamp,
  }) {
    switch (category.toLowerCase()) {
      case 'job_knowledge':
        if (rating != null) jobKnowledgeRating.setValue(rating, timestamp);
        if (score != null) jobKnowledgeScore.setValue(score, timestamp);
        if (comments != null)
          jobKnowledgeComments.setValue(comments, timestamp);
        break;
      case 'quality_of_work':
        if (rating != null) qualityOfWorkRating.setValue(rating, timestamp);
        if (score != null) qualityOfWorkScore.setValue(score, timestamp);
        if (comments != null)
          qualityOfWorkComments.setValue(comments, timestamp);
        break;
      case 'productivity':
        if (rating != null) productivityRating.setValue(rating, timestamp);
        if (score != null) productivityScore.setValue(score, timestamp);
        if (comments != null)
          productivityComments.setValue(comments, timestamp);
        break;
      case 'communication':
        if (rating != null) communicationRating.setValue(rating, timestamp);
        if (score != null) communicationScore.setValue(score, timestamp);
        if (comments != null)
          communicationComments.setValue(comments, timestamp);
        break;
      case 'teamwork':
        if (rating != null) teamworkRating.setValue(rating, timestamp);
        if (score != null) teamworkScore.setValue(score, timestamp);
        if (comments != null) teamworkComments.setValue(comments, timestamp);
        break;
      case 'leadership':
        if (rating != null) leadershipRating.setValue(rating, timestamp);
        if (score != null) leadershipScore.setValue(score, timestamp);
        if (comments != null) leadershipComments.setValue(comments, timestamp);
        break;
      case 'initiative':
        if (rating != null) initiativeRating.setValue(rating, timestamp);
        if (score != null) initiativeScore.setValue(score, timestamp);
        if (comments != null) initiativeComments.setValue(comments, timestamp);
        break;
    }
    _updateTimestamp(timestamp);
  }

  /// Update development areas
  void updateDevelopmentAreas({
    String? empStrengths,
    String? improvements,
    String? devPlan,
    String? career,
    required HLCTimestamp timestamp,
  }) {
    if (empStrengths != null) strengths.setValue(empStrengths, timestamp);
    if (improvements != null)
      areasForImprovement.setValue(improvements, timestamp);
    if (devPlan != null) developmentPlan.setValue(devPlan, timestamp);
    if (career != null) careerAspirations.setValue(career, timestamp);
    _updateTimestamp(timestamp);
  }

  /// Add goal
  void addGoal(String goalId) {
    goalIds.add(goalId);
  }

  /// Remove goal
  void removeGoal(String goalId) {
    goalIds.remove(goalId);
  }

  /// Submit for approval
  void submitForApproval(HLCTimestamp timestamp) {
    status.setValue('submitted', timestamp);
    _updateTimestamp(timestamp);
  }

  /// Complete review
  void completeReview(HLCTimestamp timestamp) {
    status.setValue('completed', timestamp);
    _updateTimestamp(timestamp);
  }

  /// Manager sign-off
  void managerSignOff({
    String? assessment,
    String? recommendations,
    required HLCTimestamp timestamp,
  }) {
    if (assessment != null) managerAssessment.setValue(assessment, timestamp);
    if (recommendations != null)
      managerRecommendations.setValue(recommendations, timestamp);
    managerSignOffDate.setValue(DateTime.now(), timestamp);
    _updateTimestamp(timestamp);
  }

  /// HR review
  void hrReview({
    String? comments,
    String? recommendations,
    required HLCTimestamp timestamp,
  }) {
    if (comments != null) hrComments.setValue(comments, timestamp);
    if (recommendations != null)
      hrRecommendations.setValue(recommendations, timestamp);
    hrReviewDate.setValue(DateTime.now(), timestamp);
    _updateTimestamp(timestamp);
  }

  void _updateTimestamp(HLCTimestamp timestamp) {
    if (timestamp.happensAfter(updatedAt)) {
      updatedAt = timestamp;
      version = version.tick();
    }
  }

  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTPerformanceRecord || other.id != id) {
      throw ArgumentError('Cannot merge with different performance record');
    }

    // Merge all CRDT fields
    employeeId.mergeWith(other.employeeId);
    reviewerId.mergeWith(other.reviewerId);
    reviewPeriod.mergeWith(other.reviewPeriod);
    reviewStartDate.mergeWith(other.reviewStartDate);
    reviewEndDate.mergeWith(other.reviewEndDate);
    reviewDueDate.mergeWith(other.reviewDueDate);
    status.mergeWith(other.status);
    reviewType.mergeWith(other.reviewType);

    overallRating.mergeWith(other.overallRating);
    overallScore.mergeWith(other.overallScore);
    overallComments.mergeWith(other.overallComments);

    jobKnowledgeRating.mergeWith(other.jobKnowledgeRating);
    jobKnowledgeScore.mergeWith(other.jobKnowledgeScore);
    jobKnowledgeComments.mergeWith(other.jobKnowledgeComments);

    qualityOfWorkRating.mergeWith(other.qualityOfWorkRating);
    qualityOfWorkScore.mergeWith(other.qualityOfWorkScore);
    qualityOfWorkComments.mergeWith(other.qualityOfWorkComments);

    productivityRating.mergeWith(other.productivityRating);
    productivityScore.mergeWith(other.productivityScore);
    productivityComments.mergeWith(other.productivityComments);

    communicationRating.mergeWith(other.communicationRating);
    communicationScore.mergeWith(other.communicationScore);
    communicationComments.mergeWith(other.communicationComments);

    teamworkRating.mergeWith(other.teamworkRating);
    teamworkScore.mergeWith(other.teamworkScore);
    teamworkComments.mergeWith(other.teamworkComments);

    leadershipRating.mergeWith(other.leadershipRating);
    leadershipScore.mergeWith(other.leadershipScore);
    leadershipComments.mergeWith(other.leadershipComments);

    initiativeRating.mergeWith(other.initiativeRating);
    initiativeScore.mergeWith(other.initiativeScore);
    initiativeComments.mergeWith(other.initiativeComments);

    strengths.mergeWith(other.strengths);
    areasForImprovement.mergeWith(other.areasForImprovement);
    developmentPlan.mergeWith(other.developmentPlan);
    careerAspirations.mergeWith(other.careerAspirations);

    goalIds.mergeWith(other.goalIds);

    trainingNeeds.mergeWith(other.trainingNeeds);
    skillGaps.mergeWith(other.skillGaps);
    mentorshipNeeds.mergeWith(other.mentorshipNeeds);

    selfAssessment.mergeWith(other.selfAssessment);
    selfRating.mergeWith(other.selfRating);
    selfScore.mergeWith(other.selfScore);
    employeeComments.mergeWith(other.employeeComments);

    managerAssessment.mergeWith(other.managerAssessment);
    managerRecommendations.mergeWith(other.managerRecommendations);
    managerSignOffDate.mergeWith(other.managerSignOffDate);

    hrComments.mergeWith(other.hrComments);
    hrReviewDate.mergeWith(other.hrReviewDate);
    hrRecommendations.mergeWith(other.hrRecommendations);

    actionItems.mergeWith(other.actionItems);
    nextReviewDate.mergeWith(other.nextReviewDate);
    followUpRequired.mergeWith(other.followUpRequired);

    salaryIncreaseRecommended.mergeWith(other.salaryIncreaseRecommended);
    recommendedSalaryIncrease.mergeWith(other.recommendedSalaryIncrease);
    promotionRecommended.mergeWith(other.promotionRecommended);
    recommendedPosition.mergeWith(other.recommendedPosition);
    recommendedEffectiveDate.mergeWith(other.recommendedEffectiveDate);

    metadata.mergeWith(other.metadata);

    // Update version and timestamp
    version = version.update(other.version);
    if (other.updatedAt.happensAfter(updatedAt)) {
      updatedAt = other.updatedAt;
    }

    // Handle deletion
    isDeleted = isDeleted || other.isDeleted;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId.value,
      'reviewer_id': reviewerId.value,
      'review_period': reviewPeriod.value,
      'review_start_date': reviewStartDate.value.millisecondsSinceEpoch,
      'review_end_date': reviewEndDate.value.millisecondsSinceEpoch,
      'review_due_date': reviewDueDate.value?.millisecondsSinceEpoch,
      'status': status.value,
      'review_type': reviewType.value,
      'is_overdue': isOverdue,
      'is_completed': isCompleted,
      'overall_rating': overallRating.value,
      'overall_score': overallScore.value,
      'overall_comments': overallComments.value,
      'average_score': averageScore,
      'job_knowledge_rating': jobKnowledgeRating.value,
      'job_knowledge_score': jobKnowledgeScore.value,
      'job_knowledge_comments': jobKnowledgeComments.value,
      'quality_of_work_rating': qualityOfWorkRating.value,
      'quality_of_work_score': qualityOfWorkScore.value,
      'quality_of_work_comments': qualityOfWorkComments.value,
      'productivity_rating': productivityRating.value,
      'productivity_score': productivityScore.value,
      'productivity_comments': productivityComments.value,
      'communication_rating': communicationRating.value,
      'communication_score': communicationScore.value,
      'communication_comments': communicationComments.value,
      'teamwork_rating': teamworkRating.value,
      'teamwork_score': teamworkScore.value,
      'teamwork_comments': teamworkComments.value,
      'leadership_rating': leadershipRating.value,
      'leadership_score': leadershipScore.value,
      'leadership_comments': leadershipComments.value,
      'initiative_rating': initiativeRating.value,
      'initiative_score': initiativeScore.value,
      'initiative_comments': initiativeComments.value,
      'strengths': strengths.value,
      'areas_for_improvement': areasForImprovement.value,
      'development_plan': developmentPlan.value,
      'career_aspirations': careerAspirations.value,
      'goal_ids': goalIds.elements.toList(),
      'training_needs': trainingNeeds.value,
      'skill_gaps': skillGaps.value,
      'mentorship_needs': mentorshipNeeds.value,
      'self_assessment': selfAssessment.value,
      'self_rating': selfRating.value,
      'self_score': selfScore.value,
      'employee_comments': employeeComments.value,
      'manager_assessment': managerAssessment.value,
      'manager_recommendations': managerRecommendations.value,
      'manager_sign_off_date': managerSignOffDate.value?.millisecondsSinceEpoch,
      'hr_comments': hrComments.value,
      'hr_review_date': hrReviewDate.value?.millisecondsSinceEpoch,
      'hr_recommendations': hrRecommendations.value,
      'action_items': actionItems.value,
      'next_review_date': nextReviewDate.value?.millisecondsSinceEpoch,
      'follow_up_required': followUpRequired.value,
      'salary_increase_recommended': salaryIncreaseRecommended.value,
      'recommended_salary_increase': recommendedSalaryIncrease.value,
      'promotion_recommended': promotionRecommended.value,
      'recommended_position': recommendedPosition.value,
      'recommended_effective_date':
          recommendedEffectiveDate.value?.millisecondsSinceEpoch,
      'metadata': metadata.value,
      'is_deleted': isDeleted,
      'created_at': createdAt.physicalTime,
      'updated_at': updatedAt.physicalTime,
    };
  }

  @override
  Map<String, dynamic> toCRDTJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'created_at': createdAt.toString(),
      'updated_at': updatedAt.toString(),
      'version': version.toString(),
      'is_deleted': isDeleted,
      'employee_id': employeeId.toJson(),
      'reviewer_id': reviewerId.toJson(),
      'review_period': reviewPeriod.toJson(),
      'review_start_date': reviewStartDate.toJson(),
      'review_end_date': reviewEndDate.toJson(),
      'review_due_date': reviewDueDate.toJson(),
      'status': status.toJson(),
      'review_type': reviewType.toJson(),
      'overall_rating': overallRating.toJson(),
      'overall_score': overallScore.toJson(),
      'overall_comments': overallComments.toJson(),
      'job_knowledge_rating': jobKnowledgeRating.toJson(),
      'job_knowledge_score': jobKnowledgeScore.toJson(),
      'job_knowledge_comments': jobKnowledgeComments.toJson(),
      'quality_of_work_rating': qualityOfWorkRating.toJson(),
      'quality_of_work_score': qualityOfWorkScore.toJson(),
      'quality_of_work_comments': qualityOfWorkComments.toJson(),
      'productivity_rating': productivityRating.toJson(),
      'productivity_score': productivityScore.toJson(),
      'productivity_comments': productivityComments.toJson(),
      'communication_rating': communicationRating.toJson(),
      'communication_score': communicationScore.toJson(),
      'communication_comments': communicationComments.toJson(),
      'teamwork_rating': teamworkRating.toJson(),
      'teamwork_score': teamworkScore.toJson(),
      'teamwork_comments': teamworkComments.toJson(),
      'leadership_rating': leadershipRating.toJson(),
      'leadership_score': leadershipScore.toJson(),
      'leadership_comments': leadershipComments.toJson(),
      'initiative_rating': initiativeRating.toJson(),
      'initiative_score': initiativeScore.toJson(),
      'initiative_comments': initiativeComments.toJson(),
      'strengths': strengths.toJson(),
      'areas_for_improvement': areasForImprovement.toJson(),
      'development_plan': developmentPlan.toJson(),
      'career_aspirations': careerAspirations.toJson(),
      'goal_ids': goalIds.toJson(),
      'training_needs': trainingNeeds.toJson(),
      'skill_gaps': skillGaps.toJson(),
      'mentorship_needs': mentorshipNeeds.toJson(),
      'self_assessment': selfAssessment.toJson(),
      'self_rating': selfRating.toJson(),
      'self_score': selfScore.toJson(),
      'employee_comments': employeeComments.toJson(),
      'manager_assessment': managerAssessment.toJson(),
      'manager_recommendations': managerRecommendations.toJson(),
      'manager_sign_off_date': managerSignOffDate.toJson(),
      'hr_comments': hrComments.toJson(),
      'hr_review_date': hrReviewDate.toJson(),
      'hr_recommendations': hrRecommendations.toJson(),
      'action_items': actionItems.toJson(),
      'next_review_date': nextReviewDate.toJson(),
      'follow_up_required': followUpRequired.toJson(),
      'salary_increase_recommended': salaryIncreaseRecommended.toJson(),
      'recommended_salary_increase': recommendedSalaryIncrease.toJson(),
      'promotion_recommended': promotionRecommended.toJson(),
      'recommended_position': recommendedPosition.toJson(),
      'recommended_effective_date': recommendedEffectiveDate.toJson(),
      'metadata': metadata.toJson(),
    };
  }
}

/// CRDT-enabled Goal model for employee performance tracking
class CRDTEmployeeGoal implements CRDTModel {
  @override
  final String id;

  @override
  final String nodeId;

  @override
  final HLCTimestamp createdAt;

  @override
  HLCTimestamp updatedAt;

  @override
  CRDTVectorClock version;

  @override
  bool isDeleted;

  late LWWRegister<String> employeeId;
  late LWWRegister<String?> performanceRecordId;
  late LWWRegister<String> goalTitle;
  late LWWRegister<String?> goalDescription;
  late LWWRegister<String>
      status; // not_started, in_progress, completed, overdue, cancelled
  late LWWRegister<String> priority; // low, medium, high, critical
  late LWWRegister<DateTime> targetDate;
  late LWWRegister<DateTime?> completedDate;
  late LWWRegister<double> progressPercentage;
  late LWWRegister<String?> notes;
  late LWWRegister<String?> managerComments;
  late LWWRegister<Map<String, dynamic>?> metadata;

  CRDTEmployeeGoal({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String empId,
    String? performanceId,
    required String title,
    String? description,
    String goalStatus = 'not_started',
    String goalPriority = 'medium',
    required DateTime target,
    DateTime? completed,
    double progress = 0.0,
    String? goalNotes,
    String? managerComment,
    Map<String, dynamic>? goalMetadata,
    this.isDeleted = false,
  }) {
    employeeId = LWWRegister(empId, createdAt);
    performanceRecordId = LWWRegister(performanceId, createdAt);
    goalTitle = LWWRegister(title, createdAt);
    goalDescription = LWWRegister(description, createdAt);
    status = LWWRegister(goalStatus, createdAt);
    priority = LWWRegister(goalPriority, createdAt);
    targetDate = LWWRegister(target, createdAt);
    completedDate = LWWRegister(completed, createdAt);
    progressPercentage = LWWRegister(progress, createdAt);
    notes = LWWRegister(goalNotes, createdAt);
    managerComments = LWWRegister(managerComment, createdAt);
    metadata = LWWRegister(goalMetadata, createdAt);
  }

  /// Check if goal is overdue
  bool get isOverdue {
    return DateTime.now().isAfter(targetDate.value) &&
        status.value != 'completed';
  }

  /// Check if goal is completed
  bool get isCompleted => status.value == 'completed';

  /// Update progress
  void updateProgress(double newProgress, HLCTimestamp timestamp) {
    progressPercentage.setValue(newProgress.clamp(0.0, 100.0), timestamp);

    // Auto-complete if 100%
    if (newProgress >= 100.0 && status.value != 'completed') {
      status.setValue('completed', timestamp);
      completedDate.setValue(DateTime.now(), timestamp);
    }
    _updateTimestamp(timestamp);
  }

  /// Complete goal
  void completeGoal(HLCTimestamp timestamp) {
    status.setValue('completed', timestamp);
    completedDate.setValue(DateTime.now(), timestamp);
    progressPercentage.setValue(100.0, timestamp);
    _updateTimestamp(timestamp);
  }

  void _updateTimestamp(HLCTimestamp timestamp) {
    if (timestamp.happensAfter(updatedAt)) {
      updatedAt = timestamp;
      version = version.tick();
    }
  }

  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTEmployeeGoal || other.id != id) {
      throw ArgumentError('Cannot merge with different employee goal');
    }

    employeeId.mergeWith(other.employeeId);
    performanceRecordId.mergeWith(other.performanceRecordId);
    goalTitle.mergeWith(other.goalTitle);
    goalDescription.mergeWith(other.goalDescription);
    status.mergeWith(other.status);
    priority.mergeWith(other.priority);
    targetDate.mergeWith(other.targetDate);
    completedDate.mergeWith(other.completedDate);
    progressPercentage.mergeWith(other.progressPercentage);
    notes.mergeWith(other.notes);
    managerComments.mergeWith(other.managerComments);
    metadata.mergeWith(other.metadata);

    version = version.update(other.version);
    if (other.updatedAt.happensAfter(updatedAt)) {
      updatedAt = other.updatedAt;
    }

    isDeleted = isDeleted || other.isDeleted;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId.value,
      'performance_record_id': performanceRecordId.value,
      'goal_title': goalTitle.value,
      'goal_description': goalDescription.value,
      'status': status.value,
      'priority': priority.value,
      'target_date': targetDate.value.millisecondsSinceEpoch,
      'completed_date': completedDate.value?.millisecondsSinceEpoch,
      'progress_percentage': progressPercentage.value,
      'is_overdue': isOverdue,
      'is_completed': isCompleted,
      'notes': notes.value,
      'manager_comments': managerComments.value,
      'metadata': metadata.value,
      'is_deleted': isDeleted,
      'created_at': createdAt.physicalTime,
      'updated_at': updatedAt.physicalTime,
    };
  }

  @override
  Map<String, dynamic> toCRDTJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'created_at': createdAt.toString(),
      'updated_at': updatedAt.toString(),
      'version': version.toString(),
      'is_deleted': isDeleted,
      'employee_id': employeeId.toJson(),
      'performance_record_id': performanceRecordId.toJson(),
      'goal_title': goalTitle.toJson(),
      'goal_description': goalDescription.toJson(),
      'status': status.toJson(),
      'priority': priority.toJson(),
      'target_date': targetDate.toJson(),
      'completed_date': completedDate.toJson(),
      'progress_percentage': progressPercentage.toJson(),
      'notes': notes.toJson(),
      'manager_comments': managerComments.toJson(),
      'metadata': metadata.toJson(),
    };
  }
}
