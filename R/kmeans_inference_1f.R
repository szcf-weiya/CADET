#' Perform k-means clustering on a data matrix.
#'
#' @param X Numeric matrix; \eqn{n} by \eqn{q} matrix of observed data
#' @param k Integer; the number of clusters for k-means clustering
#' @param iter.max Positive integer; 	the maximum number of iterations allowed in k-means clustering (Lloyd's) algorithm.
#' Default to \code{10}.
#' @param seed Random seed for the initialization in k-means clustering algorithm.
#'
#' @details
#' For best rendering of the equations, visit https://yiqunchen.github.io/CADET/reference/index.html.
#'
#' The data X is clustered by k-means clustering, which aims to partition the points into k groups such that the sum of squares from points
#' to the assigned cluster centers is minimized. In other words, k-means clustering solves
#' the following optimization problem
#' \deqn{ \sum_{k=1}^K \sum_{i \in C_k} \big\Vert x_i - \sum_{i \in C_k} x_i/|C_k| \big\Vert_2^2 , }
#'  subject the constraint that \eqn{C_1,..., {C}_K} forms a partition of the integers \eqn{1,..., n}.
#' The algorithm from Lloyd (1957) (also proposed in MacQueen (1967)) is used to produce a solution.
#'
#' This function is a re-implementation of the kmeans function in base R (i.e., the stats package) that
#' stores all the intermediate clustering assignments as well (see Section 3 of our manuscript for details).
#' Ouputs from these two functions agree on their estimated clusters, as well as their ordering.
#'
#' N.B.: the kmeans function in base R was implemented in Fortran and C, while our implementation is entirely in R.
#' As a result, there might be corner cases where these two functions disagree.
#' @return Returns a list with the following elements:
#' \itemize{
#' \item \code{final_cluster} Estimated clusters via k-means clustering
#' \item \code{centers} A matrix of the cluster centroids.
#' \item \code{objective} The objective function at the final iteration of k-means algorithm.
#' }
#' @examples
#' library(CADET)
#' library(ggplot2)
#' set.seed(2022)
#' n <- 150
#' true_clusters <- c(rep(1, 50), rep(2, 50), rep(3, 50))
#' delta <- 10
#' q <- 2
#' mu <- rbind(
#'   c(delta / 2, rep(0, q - 1)),
#'   c(rep(0, q - 1), sqrt(3) * delta / 2),
#'   c(-delta / 2, rep(0, q - 1))
#' )
#' sig <- 1
#' # Generate a matrix normal sample
#' X <- matrix(rnorm(n * q, sd = sig), n, q) + mu[true_clusters, ]
#' # Visualize the data
#' ggplot(data.frame(X), aes(x = X1, y = X2)) +
#'   geom_point(cex = 2) +
#'   xlab("Feature 1") +
#'   ylab("Feature 2") +
#'   theme_classic(base_size = 18) +
#'   theme(legend.position = "none") +
#'   scale_colour_manual(values = c("dodgerblue3", "rosybrown", "orange")) +
#'   theme(
#'     legend.title = element_blank(),
#'     plot.title = element_text(hjust = 0.5)
#'   )
#' k <- 3
#' # Run k-means clustering with K=3
#' estimated_clusters <- kmeans_estimation(X, k, iter.max = 20, seed = 2021)$final_cluster
#' table(true_clusters, estimated_clusters)
#' # Visualize the clusters
#' ggplot(data.frame(X), aes(x = X1, y = X2, col = as.factor(estimated_clusters))) +
#'   geom_point(cex = 2) +
#'   xlab("Feature 1") +
#'   ylab("Feature 2") +
#'   theme_classic(base_size = 18) +
#'   theme(legend.position = "none") +
#'   scale_colour_manual(values = c("dodgerblue3", "rosybrown", "orange")) +
#'   theme(legend.title = element_blank(), plot.title = element_text(hjust = 0.5))
#' @references
#' Lloyd, S. P. (1957, 1982). Least squares quantization in PCM. Technical Note, Bell Laboratories.
#' Published in 1982 in IEEE Transactions on Information Theory, 28, 128–137.
#'
#' MacQueen, J. (1967). Some methods for classification and analysis of multivariate observations.
#' In Proceedings of the Fifth Berkeley Symposium on Mathematical Statistics and Probability,
#' pp. 281–297. Berkeley, CA: University of California Press.
#' @export
kmeans_estimation <- function(X, k, iter.max = 10, seed = 1234) {
  # credit: https://stackoverflow.com/questions/59679046/speed-challenge-any-faster-method-to-calculate-distance-matrix-between-rows-of
  # user: F. Privé
  fast_dist_compute <- function(x, y) {
    (outer(rowSums(x^2), rowSums(y^2), "+") - tcrossprod(x, 2 * y)) # no need to sqrt
  }
  set.seed(seed)
  if (!is.matrix(X)) stop("X should be a matrix")
  if (k >= nrow(X)) {
    stop("Cannot have more clusters than observations")
  }
  iter_T <- 0
  n <- dim(X)[1]
  p <- dim(X)[2]
  cluster_assign_list <- vector("list", length = iter.max)
  centroid_list <- vector("list", length = iter.max)
  objective_value <- vector("list", length = iter.max)
  # first set of centroids
  initial_sample <- sample(c(1:n), k, replace = F)
  current_centroid <- X[initial_sample, ]
  # first set of assignments
  distance_matrix <- fast_dist_compute(current_centroid, X) # rdist::cdist(current_centroid,X)
  current_cluster <- apply(distance_matrix, 2, which.min)
  iter_T <- iter_T + 1
  centroid_list[[iter_T]] <- current_centroid
  cluster_assign_list[[iter_T]] <- current_cluster
  curr_objective_value <- sum(apply(distance_matrix, 2, min)) # ^2 removed
  objective_diff <- 10000 # curr_objective_value; some large default
  objective_value[[iter_T]] <- curr_objective_value
  same_cluster <- FALSE
  while ((iter_T <= iter.max) & (!same_cluster)) {
    # update centroids
    for (current_k in c(1:k)) {
      X_current <- X[(current_cluster == current_k), , drop = F]
      new_centroid_k <- .colMeans(X_current, dim(X_current)[1], dim(X_current)[2])
      current_centroid[current_k, ] <- new_centroid_k # 1 by q
    } # current_centroid is k by q
    # update assignments
    distance_matrix <- fast_dist_compute(current_centroid, X) # rdist::cdist(current_centroid,X)
    current_cluster <- apply(distance_matrix, 2, which.min)
    # add iteration and store relevant information
    iter_T <- iter_T + 1
    centroid_list[[iter_T]] <- current_centroid
    cluster_assign_list[[iter_T]] <- current_cluster
    same_cluster <- all(current_cluster == cluster_assign_list[[iter_T - 1]])
    # update objective diff
    new_objective_value <- sum(apply(distance_matrix, 2, min)) # sum(apply(distance_matrix,2,min)^2)
    objective_diff <- abs(curr_objective_value - (new_objective_value)) / curr_objective_value
    curr_objective_value <- new_objective_value
    # store objextive as well
    objective_value[[iter_T]] <- curr_objective_value
  }

  result_list <- list(
    "cluster" = cluster_assign_list, "centers" = centroid_list,
    "objective" = objective_value, "iter" = iter_T,
    "final_cluster" = cluster_assign_list[[iter_T]],
    "random_init_obs" = initial_sample
  )
  return(result_list)
}

# ----- main function to test equality of the means of two estimated clusters via k-means clustering -----
#' Test for a difference in means of a single feature between clusters of observations
#' identified via k-means clustering.
#'
#' This function tests the null hypothesis of no difference in the means of a given
#' feature between a pair of clusters obtained via k-means clustering. The clusters
#' are numbered as per the results of the \code{kmeans_estimation} function in the \code{CADET} package.
#' By default, this function assumes that the features are independent. If known,
#' the variance of feature \code{feat} (\eqn{\sigma}) can be passed in using the
#' \code{sigma} argument; otherwise, an estimate of \eqn{\sigma} will be used.
#'
#' Setting \code{iso} to \code{FALSE} (default) allows the features to be dependent, i.e.
#' \eqn{Cov(X_i) = \Sigma}. \eqn{\Sigma} need to be passed in using the \code{covMat} argument.
#'
#' @param X Numeric matrix; \eqn{n} by \eqn{q} matrix of observed data
#' @param k Integer; the number of clusters for k-means clustering
#' @param cluster_1,cluster_2 Two different integers in {1,...,k}; two estimated clusters to test, as indexed by the results of
#' \code{kmeans_estimation}.
#' @param feat Integer selecting the feature to test.
#' @param iso Boolean. If \code{TRUE}, an isotropic covariance matrix model is used.
#' Default is \code{code}.
#' @param sig Numeric; noise standard deviation for the observed data, a non-negative number;
#' relevant if \code{iso}=TRUE. If it's not given as input, a median-based estimator will be by default (see Section 4.2 of our manuscript).
#' @param covMat Numeric matrix; if \code{iso} is FALSE, *required* \eqn{q} by \eqn{q} matrix specifying \eqn{\Sigma}.
#' @param iter.max Positive integer; 	the maximum number of iterations allowed in k-means clustering algorithm. Default to \code{10}.
#' @param seed Random seed for the initialization in k-means clustering algorithm.
#'
#' @return Returns a list with the following elements:
#' \itemize{
#' \item \code{p_naive} the naive p-value which ignores the fact that the clusters under consideration
#' are estimated from the same data used for testing
#' \item \code{pval} the selective p-value \eqn{p_{kmeans,j}} in Chen and Gao (2023+)
#' \item \code{final_interval} the conditioning set of Chen and Gao (2023+), stored as an \code{Intervals} class object.
#' \item \code{test_stat} test statistic: the (signed) difference in the empirical means of the
#' specified feature between two estimated clusters.
#' \item \code{final_cluster} Estimated clusters via k-means clustering.
#' }
#'
#' @export
#'
#' @details
#' For better rendering of the equations, visit https://yiqunchen.github.io/CADET/reference/index.html.
#'
#' Consider the generative model \eqn{X ~ MN(\mu,I_n,\sigma^2 I_q)}. First recall that k-means clustering
#' solves the following optimization problem
#' \deqn{ \sum_{k=1}^K \sum_{i \in C_k} \big\Vert x_i - \sum_{i \in C_k} x_i/|C_k| \big\Vert_2^2 , }
#'  where \eqn{C_1,..., C_K} forms a partition of the integers \eqn{1,..., n}, and can be regarded as
#'  the estimated clusters of the original observations. Lloyd's algorithm is an iterative apparoach to solve
#'  this optimization problem.
#' Now suppose we want to test whether the means of two estimated clusters \code{cluster_1} and \code{cluster_2}
#' are equal; or equivalently, the null hypothesis of the form \eqn{H_{0,j}:  (\mu^T \nu)_j = 0} versus
#' \eqn{H_{1,j}: (\mu^T \nu)_j \neq 0} for suitably chosen \eqn{\nu} and feature number j.
#'
#' This function computes the following p-value:
#' \deqn{P \Big( |(X^T\nu)_j| \ge |(x^T\nu)_j| \; | \;
#'   \bigcap_{t=1}^{T}\bigcap_{i=1}^{n} \{ c_i^{(t)}(X) =
#'  c_i^{(t)}( x ) \},  U(X)  =  U(x) \Big),}
#' where \eqn{c_i^{(t)}} is the is the cluster to which the \eqn{i}th observation is assigned during the \eqn{t}th iteration of
#' Lloyd's algorithm, and \eqn{U} is defined in Section 3.2 of Chen and Gao (2023+).
#' The test that rejects \eqn{H_{0,j}} when this p-value is less than \eqn{\alpha} controls the selective Type I error
#' rate at \eqn{\alpha}, and has substantial power.
#' Readers can refer to the Sections 2-4 in Chen and Gao (2023+) for more details.
#' @examples
#' library(CADET)
#' library(ggplot2)
#' set.seed(2022)
#' n <- 150
#' true_clusters <- c(rep(1, 50), rep(2, 50), rep(3, 50))
#' delta <- 10
#' q <- 2
#' mu <- rbind(
#'   c(delta / 2, rep(0, q - 1)),
#'   c(rep(0, q - 1), sqrt(3) * delta / 2),
#'   c(-delta / 2, rep(0, q - 1))
#' )
#' sig <- 1
#' # Generate a matrix normal sample
#' X <- matrix(rnorm(n * q, sd = sig), n, q) + mu[true_clusters, ]
#' # Visualize the data
#' ggplot(data.frame(X), aes(x = X1, y = X2)) +
#'   geom_point(cex = 2) +
#'   xlab("Feature 1") +
#'   ylab("Feature 2") +
#'   theme_classic(base_size = 18) +
#'   theme(legend.position = "none") +
#'   scale_colour_manual(values = c("dodgerblue3", "rosybrown", "orange")) +
#'   theme(
#'     legend.title = element_blank(),
#'     plot.title = element_text(hjust = 0.5)
#'   )
#' k <- 3
#' # Run k-means clustering with K=3
#' estimated_clusters <- kmeans_estimation(X, k, iter.max = 20, seed = 2023)$final_cluster
#' table(true_clusters, estimated_clusters)
#' # Visualize the clusters
#' ggplot(data.frame(X), aes(x = X1, y = X2, col = as.factor(estimated_clusters))) +
#'   geom_point(cex = 2) +
#'   xlab("Feature 1") +
#'   ylab("Feature 2") +
#'   theme_classic(base_size = 18) +
#'   theme(legend.position = "none") +
#'   scale_colour_manual(values = c("dodgerblue3", "rosybrown", "orange")) +
#'   theme(legend.title = element_blank(), plot.title = element_text(hjust = 0.5))
#' # Let's test the difference between first feature across estimated clusters 1 and 2:
#' cl_1_2_feat_1 <- kmeans_inference_1f(X,
#'   k = 3, 1, 2,
#'   feat = 1, iso = TRUE,
#'   sig = sig,
#'   covMat = NULL, seed = 2023,
#'   iter.max = 30
#' )
#' cl_1_2_feat_1
#' @references
#' Lloyd, S. P. (1957, 1982). Least squares quantization in PCM. Technical Note, Bell Laboratories.
#' Published in 1982 in IEEE Transactions on Information Theory, 28, 128–137.
#'
kmeans_inference_1f <- structure(function(X, k, cluster_1, cluster_2,
                                          feats, iso = FALSE, sig = NULL, covMat = NULL,
                                          iter.max = 10, seed = 1234) {
  set.seed(seed)
  if (!is.matrix(X)) stop("X should be a matrix")
  if (sum(is.na(X)) > 0) {
    stop("NA is not allowed in the input data X")
  }
  if (k >= nrow(X)) {
    stop("Cannot have more clusters than observations")
  }
  if ((iso) & (is.null(sig))) {
    cat("Variance not specified, using a robust median-based estimator by default!\n")
    estimate_MED <- function(X) {
      for (j in c(1:ncol(X))) {
        X[, j] <- X[, j] - stats::median(X[, j])
      }
      sigma_hat <- sqrt(stats::median(X^2) / stats::qchisq(1 / 2, df = 1))
      return(sigma_hat)
    }
    sig <- estimate_MED(X)
  }
  if (is.null(sig) & is.null(covMat)) {
    stop("At least one of variance and covariance matrix must be specified!")
  }
  if ((!is.null(sig)) & (!is.null(covMat))) {
    stop("Only one of variance and covariance matrix can be specified!")
  }
  if (!(iso) & (is.null(covMat))) {
    stop("You must specify covMat when iso=FALSE!\n")
  }
  if ((min(cluster_1, cluster_2) < 1) | (max(cluster_1, cluster_2) > k)) {
    stop("Cluster numbers must be between 1 and k!")
  }
  n <- dim(X)[1]
  p <- dim(X)[2]
  # get the list of all assigned clusters first
  estimated_k_means <- kmeans_estimation(X, k, iter.max, seed)
  # check if we get the desired number of clusters:
  if (length(unique(estimated_k_means$final_cluster)) < k) {
    stop("k-means clustering did not return the desired number of clusters! Try a different seed?")
  }
  estimated_final_cluster <- estimated_k_means$cluster[[estimated_k_means$iter]]
  all_T_clusters <- do.call(rbind, estimated_k_means$cluster)
  all_T_centroids <- estimated_k_means$centers
  T_length <- nrow(all_T_clusters)
  # construct contrast vector
  v_vec <- rep(0, times = nrow(X))
  v_vec[estimated_final_cluster == cluster_1] <- 1 / (sum(estimated_final_cluster == cluster_1))
  v_vec[estimated_final_cluster == cluster_2] <- -1 / (sum(estimated_final_cluster == cluster_2))

  n1 <- sum(estimated_final_cluster == cluster_1)
  n2 <- sum(estimated_final_cluster == cluster_2)
  squared_norm_nu <- 1 / n1 + 1 / n2
  v_norm <- sqrt(squared_norm_nu) # recycle this computed value
  lst_result_list = NULL
  idx_feat = 0
  for (feat in feats) {
    idx_feat = idx_feat + 1
    # compute XTv
    diff_means_feat <- mean(X[estimated_final_cluster == cluster_1, feat]) -
      mean(X[estimated_final_cluster == cluster_2, feat])
    # compute

    p_naive <- NULL
    # compute test_stat in the isotropic case
    if (!is.null(sig)) {
      test_stats <- diff_means_feat
      scale_factor <- squared_norm_nu * sig^2
      # compute S

      final_interval_TN <- kmeans_compute_S_1f_iso(
        X, estimated_k_means, all_T_clusters,
        all_T_centroids, n, diff_means_feat,
        v_vec, v_norm, T_length, k,
        feat, sig^2
      )

      # update p naive
      # p_naive <- multivariate_Z_test(X, estimated_final_cluster, cluster_1, cluster_2, sig)
    }

    # compute test_stats in the general cov case
    if (!is.null(covMat)) {
      test_stats <- diff_means_feat

      # compute S
      sig_squared <- covMat[feat, feat]
      scaledSigRow <- covMat[feat, ] / sig_squared
      scaledSigRow_2_norm <- norm_vec(scaledSigRow)

      scale_factor <- squared_norm_nu * sig_squared


      final_interval_TN <- kmeans_compute_S_1f_genCov(
        X, estimated_k_means, all_T_clusters,
        all_T_centroids, n, diff_means_feat,
        v_vec, v_norm, T_length, k,
        feat, scaledSigRow, scaledSigRow_2_norm
      )
    }

    p_naive <- naive.two.sided.pval(
      z = test_stats,
      mean = 0,
      sd = sqrt(scale_factor)
    )
    # improve numerical stability
    final_interval_TN <- intervals::interval_union(as(final_interval_TN, "Intervals_full"),
                                                   intervals::Intervals_full(c(
                                                     test_stats - (1e-09),
                                                     test_stats + (1e-09)
                                                   )),
                                                   check_valid = FALSE
    )
    # update pval at the end of the day
    # is this calc... correct tho? -- yes but only for mu = 0
    if (test_stats > 0) {
      pval <- TNSurv(test_stats, 0, sqrt(scale_factor), final_interval_TN) +
        TNSurv(test_stats, 0, sqrt(scale_factor), intervals::Intervals(as.matrix(-final_interval_TN)[, 2:1]))
    } else {
      pval <- TNSurv(-test_stats, 0, sqrt(scale_factor), final_interval_TN) +
        TNSurv(-test_stats, 0, sqrt(scale_factor), intervals::Intervals(as.matrix(-final_interval_TN)[, 2:1]))
    }

    result_list <- list(
      "final_interval" = final_interval_TN,
      "final_cluster" = estimated_final_cluster,
      "test_stat" = test_stats,
      "cluster_1" = cluster_1,
      "cluster_2" = cluster_2,
      "feat" = feat,
      "sig" = sig,
      "covMat" = covMat,
      "scale_factor" = scale_factor,
      "p_naive" = p_naive,
      "pval" = pval,
      "call" = match.call()
    )
    class(result_list) <- "kmeans_inference"
    lst_result_list[[idx_feat]] = result_list
  }

  return(lst_result_list)
})
