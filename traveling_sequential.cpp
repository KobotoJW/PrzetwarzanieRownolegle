#include <iostream>
#include <vector>
#include <chrono>
#include <limits.h>
#include <omp.h>

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

    std::vector<std::vector<int>> matrix;

    matrix = gen_matrix(numCities);
    // matrix = {
    //     {0, 39, 54, 11},
    //     {39, 0, 28, 74},
    //     {54, 28, 0, 86},
    //     {11, 74, 86, 0}
    // };

    // Result array
    std::vector<int> results(numCities, INT_MAX);
    std::vector<std::vector<int>> paths(numCities, std::vector<int>(numCities));

    auto start = std::chrono::high_resolution_clock::now();

    for (int tid = 0; tid < numCities; tid++) {
        std::vector<int> path(numCities);
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
                    int newCost = matrix[path[i-1]][j];
                    if (newCost < minCost) {
                        minCost = newCost;
                        nextCity = j;
                    }
                }
            }
            path[i] = nextCity;
            cost += matrix[path[i-1]][path[i]];
        }

        results[tid] = cost;

        paths[tid] = path;
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    std::cout << "Elapsed time: " << elapsed.count() << " µs\n";

    int minCost = INT_MAX;
    int minCostIndex = 0;
    for (int i = 0; i < numCities; i++) {
        if (results[i] < minCost) {
            minCost = results[i];
            minCostIndex = i;
        }
    }

    // // Print the cheapest path
    // printf("Cheapest path: ");
    // for (int i = 0; i < numCities; i++) {
    //     printf("%d ", paths[minCostIndex][i]);
    // }
    // printf("\n");

    printf("Minimum cost: %d\n", minCost);
    return 0;
}