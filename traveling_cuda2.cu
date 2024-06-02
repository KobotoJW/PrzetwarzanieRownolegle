#include <iostream>
#include <vector>
#include <chrono>
#include <omp.h>
#include <limits.h>
#include <cuda_runtime.h>

__global__ void tspKernel(int *d_costMatrix, int *d_results, int *d_paths, int numCities) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;

    if (tid < numCities) {
        int* path = new int[numCities];
        int cost = 0;

        path[0] = tid; // Start from the city 'tid'
        for (int i = 1; i < numCities; i++) {
            int minCost = INT_MAX;
            int nextCity = -1;
            for (int j = 0; j < numCities; j++) {
                bool visited = false;
                for (int k = 0; k < i; k++) {
                    if (path[k] == j) {
                        visited = true;
                        break;
                    }
                }
                if (!visited && j != path[i-1]) {
                    int newCost = d_costMatrix[path[i-1] * numCities + j];
                    if (newCost < minCost) {
                        minCost = newCost;
                        nextCity = j;
                    }
                }
            }
            path[i] = nextCity;
            cost += d_costMatrix[path[i-1] * numCities + path[i]];
        }

        d_results[tid] = cost;

        for (int i = 0; i < numCities; i++) {
            d_paths[tid * numCities + i] = path[i];
        }

        delete[] path;
    }
}

std::vector<std::vector<int>> gen_matrix(int num_cities) {
    srand(time(0)); // Seed

    std::vector<std::vector<int>> matrix(num_cities, std::vector<int>(num_cities));

    #pragma omp parallel for
    for (int i = 0; i < num_cities; ++i) {
        unsigned int seed = time(0) ^ (i + omp_get_thread_num());
        for (int j = i + 1; j < num_cities; ++j) {
            if (i == j) {
                matrix[i][j] = 0;
            } else {
                int cost = rand_r(&seed) % 100 + 1;

                matrix[i][j] = cost;
                matrix[j][i] = cost;
            }
        }
    }

    // //Print the matrix
    // for (int i = 0; i < num_cities; ++i) {
    //     for (int j = 0; j < num_cities; ++j) {
    //         std::cout << matrix[i][j] << ' ';
    //     }
    //     std::cout << '\n';
    // }

    return matrix;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <num_cities>\n";
        return 1;
    }

    int numCities;
    try {
        numCities = std::stoi(argv[1]);
    } catch (std::invalid_argument &e) {
        std::cerr << "Invalid number of cities\n";
        return 1;
    }

    int MAX_THREADS = numCities;
    int BLOCK_SIZE = 256;

    int* h_costMatrix = new int[numCities * numCities];
    int *d_costMatrix;

    std::vector<std::vector<int>> matrix = gen_matrix(numCities);
    for (int i = 0; i < numCities; i++) {
        for (int j = 0; j < numCities; j++) {
            h_costMatrix[i * numCities + j] = matrix[i][j];
        }
    }

    cudaMalloc(&d_costMatrix, sizeof(int) * numCities * numCities);
    cudaMemcpy(d_costMatrix, h_costMatrix, sizeof(int) * numCities * numCities, cudaMemcpyHostToDevice);

    int* h_results = new int[MAX_THREADS];
    int *d_results;
    cudaMalloc(&d_results, sizeof(int) * MAX_THREADS);

    int *d_paths;
    cudaMalloc(&d_paths, sizeof(int) * numCities * MAX_THREADS);

    int numBlocks = (numCities + BLOCK_SIZE - 1) / BLOCK_SIZE;

    auto start = std::chrono::high_resolution_clock::now();
    tspKernel<<<numBlocks, BLOCK_SIZE>>>(d_costMatrix, d_results, d_paths, numCities);
    auto end = std::chrono::high_resolution_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    std::cout << "Elapsed time: " << elapsed.count() << " µs\n";

    cudaMemcpy(h_results, d_results, sizeof(int) * MAX_THREADS, cudaMemcpyDeviceToHost);

    int* h_paths = new int[MAX_THREADS * numCities];
    cudaMemcpy(h_paths, d_paths, sizeof(int) * numCities * MAX_THREADS, cudaMemcpyDeviceToHost);

    int minCost = INT_MAX;
    int minCostIndex = 0;
    for (int i = 0; i < numCities; i++) {
        if (h_results[i] < minCost) {
            minCost = h_results[i];
            minCostIndex = i;
        }
    }

    // // Print the cheapest path
    // printf("Cheapest path: ");
    // for (int i = 0; i < numCities; i++) {
    //     printf("%d ", h_paths[minCostIndex * numCities + i]);
    // }
    // printf("\n");

    delete[] h_costMatrix;
    delete[] h_results;
    delete[] h_paths;

    cudaFree(d_paths);

    cudaFree(d_costMatrix);
    cudaFree(d_results);

    printf("Minimum cost: %d\n", minCost);
    return 0;
}
